import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../cards/card_models.dart';
import '../defer/defer_models.dart';
import '../identity/identity_models.dart';
import '../pay/payment_models.dart';
import '../shop/shop_models.dart';
import '../support/support_models.dart';
import 'plan_models.dart';

/// What Home and Plans load. Everything comes straight from the API.
class HomeData {
  HomeData({required this.customerName, required this.credit, required this.plans, this.cachedAt});
  final String customerName;
  final CreditSummary? credit;
  final List<Plan> plans;

  /// Set when this is the saved copy shown offline (G13): when it was last updated.
  final DateTime? cachedAt;

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

  Future<List<Map<String, dynamic>>> _rawPlans() async {
    final res = await api.get('/customer/instalments', query: {'status': 'all', 'limit': '50'});
    final list = res is Map ? res['plans'] : null;
    return ((list as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  static List<Plan> _parse(List<Map<String, dynamic>> raw) => raw.map(Plan.fromJson).toList();

  Future<List<Plan>> plans() async => (await plansView()).plans;

  /// The plans, or the saved copy with when it was saved if the server can't be reached (G13).
  Future<({List<Plan> plans, DateTime? cachedAt})> plansView() async {
    try {
      final raw = await _rawPlans();
      await _saveCache(plans: raw);
      return (plans: _parse(raw), cachedAt: null);
    } on ApiException catch (e) {
      final c = e.offline ? await _readCache() : null;
      if (c == null) rethrow;
      return (plans: _parse(c.plans), cachedAt: c.savedAt);
    }
  }

  /// One plan, always from the server. The Pay screen uses this, so a saved amount can never end
  /// up on a pay button (G13).
  Future<Plan> plan(int id) async {
    final res = await api.get('/customer/instalments/$id');
    if (res is! Map) throw ApiException("Couldn't load this plan.", status: 200);
    return Plan.fromJson(res.cast<String, dynamic>());
  }

  /// One plan, or its saved copy offline (G13).
  Future<({Plan plan, DateTime? cachedAt})> planView(int id) async {
    try {
      return (plan: await plan(id), cachedAt: null);
    } on ApiException catch (e) {
      final c = e.offline ? await _readCache() : null;
      final saved = c?.plans.where((p) => (p['id'] as num?)?.toInt() == id).firstOrNull;
      if (saved == null) rethrow;
      return (plan: Plan.fromJson(saved), cachedAt: c!.savedAt);
    }
  }

  Future<HomeData> home() async {
    try {
      final results = await Future.wait([api.get('/customer/dashboard/stats'), _rawPlans()]);
      final stats = results[0] is Map ? (results[0] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final raw = results[1] as List<Map<String, dynamic>>;
      await _saveCache(plans: raw, stats: {'customer_name': stats['customer_name'], 'credit': stats['credit']});
      return _homeFrom(stats, raw, null);
    } on ApiException catch (e) {
      final c = e.offline ? await _readCache() : null;
      if (c == null) rethrow;
      return _homeFrom(c.stats, c.plans, c.savedAt);
    }
  }

  static HomeData _homeFrom(Map<String, dynamic> stats, List<Map<String, dynamic>> raw, DateTime? cachedAt) {
    final credit = stats['credit'];
    return HomeData(
      customerName: (stats['customer_name'] ?? '').toString(),
      credit: credit is Map ? CreditSummary.fromJson(credit.cast<String, dynamic>()) : null,
      plans: _parse(raw),
      cachedAt: cachedAt,
    );
  }

  // ---- The offline copy (G13): Home's name and limit, and the plans list. Nothing else ----

  Future<void> _saveCache({required List<Map<String, dynamic>> plans, Map<String, dynamic>? stats}) async {
    try {
      final old = stats == null ? await _readCache() : null;
      await api.session.writeCache(
        jsonEncode({
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'stats': stats ?? old?.stats ?? const {},
          'plans': plans,
        }),
      );
    } catch (_) {
      // A cache that can't be written only means no offline copy
    }
  }

  Future<({DateTime savedAt, Map<String, dynamic> stats, List<Map<String, dynamic>> plans})?> _readCache() async {
    try {
      final text = await api.session.readCache();
      if (text == null) return null;
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final savedAt = DateTime.tryParse((j['saved_at'] ?? '').toString());
      if (savedAt == null) return null;
      return (
        savedAt: savedAt.toLocal(),
        stats: (j['stats'] is Map ? (j['stats'] as Map).cast<String, dynamic>() : <String, dynamic>{}),
        plans: ((j['plans'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Asks the server whether the app is back online (any answer counts).
  Future<void> ping() async {
    try {
      await api.get('/customer/payments/config');
    } catch (_) {}
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

  // ---- Verification details and documents (U4/U5, 2026-10-25) ----

  Future<KycState> kycDetails() async {
    final res = await api.get('/customer/kyc/details');
    if (res is! Map) throw ApiException("Couldn't load your verification details.", status: 200);
    return KycState.fromJson(res.cast<String, dynamic>());
  }

  /// Saves only the fields given (partial saves are fine). Errors are `{error, field}`.
  Future<KycState> saveKycDetails(Map<String, Object?> fields) async {
    final res = await api.put('/customer/kyc/details', fields);
    if (res is! Map) throw ApiException("Couldn't save your details.", status: 200);
    changed();
    return KycState.fromJson(res.cast<String, dynamic>());
  }

  /// Uploads one document (`front_image`, `back_image`, `salary_certificate` or
  /// `bank_statement`). Returns the server's message; reload the checklist after.
  Future<String> uploadDocument(String field, PickedDocument file) async {
    final res = await api.upload('/customer/documents/upload', {field: (file.name, file.bytes)});
    changed();
    final message = res is Map ? res['message'] : null;
    return message is String && message.isNotEmpty ? message : 'Uploaded. The team will review it.';
  }

  /// The account status (`pending`, `approved`, `active`, `restricted`) from `GET /customer/profile`.
  Future<String?> accountStatus() async {
    final res = await api.get('/customer/profile');
    final status = res is Map ? res['status'] : null;
    return status is String && status.isNotEmpty ? status : null;
  }

  // ---- Report a problem (disputes) ----

  Future<List<Dispute>> disputes() async {
    final res = await api.get('/customer/disputes');
    final list = res is Map ? res['disputes'] : null;
    return ((list as List?) ?? const []).whereType<Map>().map((e) => Dispute.fromJson(e.cast<String, dynamic>())).toList();
  }

  /// Reports a problem with a purchase. The server pauses the plan's remaining payments.
  /// Returns the server's message.
  Future<String> reportProblem({required int planId, required String reason, required String description}) async {
    final res = await api.post('/customer/disputes', {'plan_id': planId, 'reason': reason, 'description': description.trim()});
    changed();
    final message = res is Map ? res['message'] : null;
    return message is String && message.isNotEmpty ? message : 'Report sent. Your payments are paused while we review it.';
  }

  // ---- Saved cards and autopay (Paystack saves a card after a card payment) ----

  Future<List<SavedCard>> savedCards() async {
    final res = await api.get('/customer/payment-methods');
    final list = res is Map ? res['payment_methods'] : null;
    return ((list as List?) ?? const []).whereType<Map>().map((e) => SavedCard.fromJson(e.cast<String, dynamic>())).toList();
  }

  /// Turns autopay on or off for a card (the API uses PUT). Returns the server's message.
  Future<String> setAutopay(int cardId, bool on) async {
    final res = await api.put('/customer/payment-methods/$cardId', {'autopay_enabled': on});
    final message = res is Map ? res['message'] : null;
    return message is String && message.isNotEmpty ? message : 'Saved';
  }

  Future<void> removeCard(int cardId) => api.delete('/customer/payment-methods/$cardId');

  // ---- Consents ----

  Future<Consents> consents() async {
    final res = await api.get('/account/consents');
    if (res is! Map) throw ApiException("Couldn't load your settings.");
    return Consents.fromJson(res.cast<String, dynamic>());
  }

  /// Offers and news only; payment reminders and receipts come either way. Returns the server's message.
  Future<String> setMarketing(bool on) async {
    final res = await api.put('/account/consents', {'marketing_consent': on});
    final message = res is Map ? res['message'] : null;
    return message is String ? message : 'Saved';
  }

  // ---- Notifications (the in-app inbox the payment reminders write to) ----

  Future<List<AppNotification>> notifications({int page = 1}) async {
    final res = await api.get('/notifications', query: {'page': '$page', 'limit': '30'});
    final list = res is Map ? res['notifications'] : null;
    return ((list as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<int> unreadCount() async {
    final res = await api.get('/notifications/unread-count');
    return res is Map ? (res['unread_count'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<void> markNotificationRead(int id) async {
    await api.put('/notifications/$id/read');
    changed();
  }

  Future<void> markAllNotificationsRead() async {
    await api.post('/notifications/mark-all-read');
    changed();
  }
}
