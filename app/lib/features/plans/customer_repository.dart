import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../defer/defer_models.dart';
import '../identity/identity_models.dart';
import '../pay/payment_models.dart';
import '../shop/shop_models.dart';
import 'plan_models.dart';

/// What Home and Plans load. Everything comes straight from the API.
class HomeData {
  HomeData({required this.customerName, required this.credit, required this.plans});
  final String customerName;
  final CreditSummary? credit;
  final List<Plan> plans;

  NextDue? get nextDue => findNextDue(plans);
  List<Plan> get openPlans => plans.where((p) => p.open).toList();
}

/// Every customer API call the app makes (the web app's `customers.service.ts`).
/// Requests carry the customer's choices only; every amount comes back from the server.
class CustomerRepository {
  CustomerRepository(this.api);
  final ApiClient api;

  /// Bumped after anything that changes the customer's plans or orders (a verified payment,
  /// a new order), so screens kept alive in the tab bar reload.
  final changes = ValueNotifier<int>(0);
  void changed() => changes.value++;

  // ---- Plans ----

  Future<List<Plan>> plans({String status = 'all'}) async {
    final res = await api.get('/customer/instalments', query: {'status': status, 'limit': '50'});
    final list = res is Map ? res['plans'] : null;
    return ((list as List?) ?? const []).whereType<Map>().map((e) => Plan.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<Plan> plan(int id) async {
    final res = await api.get('/customer/instalments/$id');
    if (res is! Map) throw ApiException("Couldn't load this plan.");
    return Plan.fromJson(res.cast<String, dynamic>());
  }

  Future<HomeData> home() async {
    final results = await Future.wait([api.get('/customer/dashboard/stats'), plans()]);
    final stats = results[0] is Map ? (results[0] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final credit = stats['credit'];
    return HomeData(
      customerName: (stats['customer_name'] ?? '').toString(),
      credit: credit is Map ? CreditSummary.fromJson(credit.cast<String, dynamic>()) : null,
      plans: results[1] as List<Plan>,
    );
  }

  Future<CreditSummary?> credit() async {
    final res = await api.get('/customer/credit');
    return res is Map ? CreditSummary.fromJson(res.cast<String, dynamic>()) : null;
  }

  // ---- Paying ----

  /// Whether online payment (Paystack) is switched on.
  Future<bool> paystackEnabled() async {
    final res = await api.get('/customer/payments/config');
    return res is Map && res['paystack_enabled'] == true;
  }

  /// Starts a Paystack payment on a plan. With no options the server charges the next payment
  /// plus any unpaid late fee; [partAmount] pays part of it; [settle] pays off the whole plan.
  Future<CheckoutStart> startPlanPayment(int planId, {int? partAmount, bool settle = false}) async {
    final body = <String, Object>{'plan_id': planId};
    if (settle) {
      body['settle'] = true;
    } else if (partAmount != null) {
      body['amount'] = pesewasToApi(partAmount);
    }
    return _checkout(await api.post('/customer/payments/paystack/initialize', body));
  }

  Future<SettlementQuote> settlementQuote(int planId) async {
    final res = await api.get('/customer/plans/$planId/settlement-quote');
    if (res is! Map) throw ApiException("Couldn't work out what's left to pay.");
    return SettlementQuote.fromJson(res.cast<String, dynamic>());
  }

  Future<PaymentResult> verifyPayment(String reference) async {
    final res = await api.get('/customer/payments/paystack/verify/${Uri.encodeComponent(reference)}');
    if (res is! Map) throw ApiException("We couldn't confirm the payment yet.");
    return PaymentResult.fromJson(res.cast<String, dynamic>());
  }

  static CheckoutStart _checkout(Object? res) {
    final start = CheckoutStart.tryParse(res);
    if (start == null) throw ApiException('Could not start the payment. Please try again.', body: res);
    return start;
  }

  // ---- Deferment (§4) ----

  Future<DefermentQuote> defermentQuote(int planId, {int? paymentId}) async {
    final res = await api.get(
      '/customer/plans/$planId/deferment',
      query: paymentId == null ? null : {'payment_id': '$paymentId'},
    );
    if (res is! Map) throw ApiException("Couldn't check whether this payment can be deferred.");
    return DefermentQuote.fromJson(res.cast<String, dynamic>());
  }

  /// Starts paying the deferment fee. The dates only move once Paystack confirms it.
  Future<CheckoutStart> startDeferment(int planId, int paymentId) async =>
      _checkout(await api.post('/customer/plans/$planId/deferment', {'payment_id': paymentId, 'agree': true}));

  // ---- Shop and checkout ----

  Future<ProductPage> products({int page = 1, String search = '', String category = ''}) async {
    final query = {'page': '$page', 'limit': '20', 'status': 'active'};
    if (search.trim().isNotEmpty) query['search'] = search.trim();
    if (category.isNotEmpty) query['category'] = category;
    final res = await api.get('/customer/products', query: query);
    final m = res is Map ? res : const {};
    return ProductPage(
      products: ((m['products'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList(),
      page: (m['page'] as num?)?.toInt() ?? page,
      totalPages: (m['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<List<String>> categories() async {
    final res = await api.get('/customer/products/categories');
    final list = res is Map ? res['categories'] : null;
    return ((list as List?) ?? const [])
        .whereType<Map>()
        .map((c) => (c['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<Product> product(int id) async {
    final res = await api.get('/customer/products/$id');
    if (res is! Map) throw ApiException("Couldn't load this product.");
    return Product.fromJson(res.cast<String, dynamic>());
  }

  /// Every plan for a product, priced by the server for this customer.
  Future<PlanOptions> planOptions(int productId, {int quantity = 1}) async {
    final res = await api.post('/customer/plan-options', {'product_id': productId, 'quantity': quantity});
    if (res is! Map) throw ApiException("We couldn't price this product right now. Please try again.");
    return PlanOptions.fromJson(res.cast<String, dynamic>());
  }

  /// Places the order. Only the choice is sent: the server prices it from the stored product.
  /// Returns the Paystack checkout for Payment 1, or null when the order went straight to
  /// approval (Paystack off) or the payment page couldn't open (pay it from My orders).
  Future<({CheckoutStart? checkout, String message})> purchase({
    required int productId,
    required int quantity,
    required int numberOfPayments,
    required String deliveryAddress,
    required bool acceptTerms,
  }) async {
    final res = await api.post('/customer/purchase', {
      'product_id': productId,
      'quantity': quantity,
      'number_of_installments': numberOfPayments,
      'delivery_address': deliveryAddress.trim(),
      'accept_terms': acceptTerms,
    });
    changed();
    final message = res is Map ? (res['message'] ?? '').toString() : '';
    return (checkout: CheckoutStart.tryParse(res), message: message);
  }

  Future<List<Order>> orders() async {
    final res = await api.get('/customer/orders');
    final list = res is Map ? res['orders'] : res;
    return ((list as List?) ?? const []).whereType<Map>().map((e) => Order.fromJson(e.cast<String, dynamic>())).toList();
  }

  /// Pays an order's down payment again (the first checkout was closed or failed).
  Future<CheckoutStart> payOrder(int orderId) async => _checkout(await api.post('/customer/orders/$orderId/pay'));

  // ---- Identity (Smile ID) ----

  Future<IdentityStatus> identity() async {
    final res = await api.get('/customer/identity');
    if (res is! Map) throw ApiException("Couldn't load your verification status.");
    return IdentityStatus.fromJson(res.cast<String, dynamic>());
  }

  Future<IdentitySession> startIdentityCheck() async {
    final session = IdentitySession.tryParse(await api.post('/customer/identity/start', {'consent': true}));
    if (session == null) throw ApiException('Could not start the check. Please try again.');
    return session;
  }

  Future<void> identitySubmitted(int checkId, String jobId) =>
      api.post('/customer/identity/$checkId/submitted', {'job_id': jobId});
}
