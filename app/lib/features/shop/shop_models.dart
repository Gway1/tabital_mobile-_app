import '../../core/format.dart';
import '../plans/plan_models.dart';

/// The Pay in 4 teaser on a product card, priced by the server for this customer.
class SplitPreview {
  SplitPreview({
    required this.downPayment,
    required this.installments,
    required this.installmentAmount,
    required this.deliveryFee,
  });
  final int downPayment;
  final int installments;
  final int installmentAmount;
  final int deliveryFee;

  static SplitPreview? fromJson(Object? j) {
    if (j is! Map) return null;
    return SplitPreview(
      downPayment: toPesewas(j['down_payment']) ?? 0,
      installments: (j['installments'] as num?)?.toInt() ?? 0,
      installmentAmount: toPesewas(j['installment_amount']) ?? 0,
      deliveryFee: toPesewas(j['delivery_fee']) ?? 0,
    );
  }
}

/// A product, from `GET /customer/products` or `GET /customer/products/<id>`.
class Product {
  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.brand,
    required this.price,
    required this.stock,
    required this.image,
    required this.merchantName,
    this.split,
  });

  final int id;
  final String name;
  final String description;
  final String category;
  final String brand;
  final int price;
  final int stock;
  final String image; // a URL or base64 image data, as merchants upload it
  final String merchantName;
  final SplitPreview? split;

  bool get inStock => stock > 0;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    category: (j['category'] ?? '').toString(),
    brand: (j['brand'] ?? '').toString(),
    price: toPesewas(j['price']) ?? 0,
    stock: (j['stock_quantity'] as num?)?.toInt() ?? 0,
    image: (j['main_image'] ?? '').toString(),
    merchantName: (j['merchant_name'] ?? '').toString(),
    split: SplitPreview.fromJson(j['split_preview']),
  );
}

class ProductPage {
  ProductPage({required this.products, required this.page, required this.totalPages});
  final List<Product> products;
  final int page;
  final int totalPages;
}

/// One payment in a quoted schedule (before the order exists).
class QuoteLine {
  QuoteLine({
    required this.number,
    required this.amount,
    required this.deliveryFee,
    required this.dueDate,
    required this.description,
  });
  final int number;
  final int amount; // includes the delivery fee on Payment 1
  final int deliveryFee;
  final DateTime? dueDate;
  final String description;

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
    number: (j['installment_number'] as num?)?.toInt() ?? 0,
    amount: toPesewas(j['amount']) ?? 0,
    deliveryFee: toPesewas(j['delivery_fee']) ?? 0,
    dueDate: parseApiDate(j['due_date']),
    description: (j['description'] ?? '').toString(),
  );
}

/// One plan for a product (Pay in full, Pay in 2, 3 or 4), priced by the server.
class PlanOption {
  PlanOption({
    required this.nPayments,
    required this.label,
    required this.dueNow,
    required this.downPayment,
    required this.downPaymentPercentage,
    required this.deliveryFee,
    required this.installments,
    required this.installmentAmount,
    required this.totalPayable,
    required this.schedule,
    required this.available,
    required this.blockedReason,
  });

  final int nPayments;
  final String label;
  final int dueNow; // Payment 1: down payment + delivery fee
  final int downPayment;
  final String downPaymentPercentage; // as the server sent it, for display only
  final int deliveryFee;
  final int installments;
  final int installmentAmount;
  final int totalPayable;
  final List<QuoteLine> schedule;
  final bool available;
  final String? blockedReason;

  bool get usesCredit => nPayments > 1;

  factory PlanOption.fromJson(Map<String, dynamic> j) {
    final pct = j['down_payment_percentage'];
    return PlanOption(
      nPayments: (j['n_payments'] as num?)?.toInt() ?? 1,
      label: (j['label'] ?? '').toString(),
      dueNow: toPesewas(j['due_now']) ?? 0,
      downPayment: toPesewas(j['down_payment']) ?? 0,
      downPaymentPercentage: pct is num ? (pct == pct.roundToDouble() ? pct.toInt().toString() : pct.toString()) : '',
      deliveryFee: toPesewas(j['delivery_fee']) ?? 0,
      installments: (j['installments'] as num?)?.toInt() ?? 0,
      installmentAmount: toPesewas(j['installment_amount']) ?? 0,
      totalPayable: toPesewas(j['total_payable']) ?? 0,
      schedule:
          ((j['payment_schedule'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => QuoteLine.fromJson(e.cast<String, dynamic>()))
              .toList()
            ..sort((a, b) => a.number.compareTo(b.number)),
      available: j['available'] != false,
      blockedReason: j['blocked_reason']?.toString(),
    );
  }
}

/// Disclosures shown before the customer commits. Every figure is the server's setting.
class KeyFacts {
  KeyFacts({
    required this.lateFeePercentage,
    required this.secondLateFeePercentage,
    required this.secondLateFeeAfterDays,
    required this.lateFeeCapPercentage,
    required this.defermentEnabled,
    required this.defermentFeePercentage,
    required this.defermentMaxPerPlan,
    required this.defermentMonths,
    required this.disputeResolutionDays,
    required this.termsUrl,
    required this.privacyUrl,
  });

  final String lateFeePercentage;
  final String secondLateFeePercentage;
  final int secondLateFeeAfterDays;
  final String lateFeeCapPercentage;
  final bool defermentEnabled;
  final String defermentFeePercentage;
  final int defermentMaxPerPlan;
  final int defermentMonths;
  final int disputeResolutionDays;
  final String? termsUrl;
  final String? privacyUrl;

  bool get hasLateFee => lateFeePercentage != '0';

  static String _pct(Object? v) {
    if (v is! num) return '0';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static KeyFacts? fromJson(Object? j) {
    if (j is! Map) return null;
    String? url(Object? v) => v is String && v.startsWith('https://') ? v : null;
    return KeyFacts(
      lateFeePercentage: _pct(j['late_fee_percentage']),
      secondLateFeePercentage: _pct(j['second_late_fee_percentage']),
      secondLateFeeAfterDays: (j['second_late_fee_after_days'] as num?)?.toInt() ?? 0,
      lateFeeCapPercentage: _pct(j['late_fee_cap_percentage']),
      defermentEnabled: j['deferment_enabled'] == true,
      defermentFeePercentage: _pct(j['deferment_fee_percentage']),
      defermentMaxPerPlan: (j['deferment_max_per_plan'] as num?)?.toInt() ?? 0,
      defermentMonths: (j['deferment_months'] as num?)?.toInt() ?? 1,
      disputeResolutionDays: (j['dispute_resolution_days'] as num?)?.toInt() ?? 0,
      termsUrl: url(j['terms_url']),
      privacyUrl: url(j['privacy_url']),
    );
  }
}

/// `POST /customer/plan-options`: every plan for one product, the customer's credit check and
/// the key facts. The app shows these figures and never works out its own.
class PlanOptions {
  PlanOptions({
    required this.productPrice,
    required this.quantity,
    required this.options,
    required this.credit,
    required this.keyFacts,
  });
  final int productPrice;
  final int quantity;
  final List<PlanOption> options;
  final CreditSummary? credit;
  final KeyFacts? keyFacts;

  PlanOption? option(int n) {
    for (final o in options) {
      if (o.nPayments == n) return o;
    }
    return null;
  }

  factory PlanOptions.fromJson(Map<String, dynamic> j) {
    const order = [4, 3, 2, 1]; // Pay in 4 first (the main plan), paying in full last
    final credit = j['credit'];
    return PlanOptions(
      productPrice: toPesewas(j['product_price']) ?? 0,
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      options:
          ((j['options'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => PlanOption.fromJson(e.cast<String, dynamic>()))
              .where((o) => order.contains(o.nPayments))
              .toList()
            ..sort((a, b) => order.indexOf(a.nPayments).compareTo(order.indexOf(b.nPayments))),
      credit: credit is Map ? CreditSummary.fromJson(credit.cast<String, dynamic>()) : null,
      keyFacts: KeyFacts.fromJson(j['key_facts']),
    );
  }
}

/// A purchase order, from `GET /customer/orders`.
class Order {
  Order({
    required this.id,
    required this.orderRef,
    required this.productName,
    required this.status,
    required this.dueNow,
    required this.totalPayable,
    required this.numberOfPayments,
    required this.refundStatus,
    required this.createdAt,
  });

  final int id;
  final String orderRef;
  final String productName;
  final String status; // awaiting_payment, pending, approved, rejected, completed, cancelled
  final int dueNow;
  final int totalPayable;
  final int numberOfPayments;
  final String refundStatus;
  final DateTime? createdAt;

  bool get awaitingDownPayment => status == 'awaiting_payment';

  String get statusLabel => switch (status) {
    'awaiting_payment' => 'Awaiting down payment',
    'pending' => 'Awaiting approval',
    _ => status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
  };

  /// The web app's refund wording, or null.
  String? get refundNote => switch (refundStatus) {
    'refunded' => 'Your down payment is being refunded',
    'refund_required' || 'refund_failed' || 'manual_refund_required' => 'Your down payment will be refunded by our team',
    _ => null,
  };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: (j['id'] as num?)?.toInt() ?? 0,
    orderRef: (j['order_id'] ?? '').toString(),
    productName: (j['product_name'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    dueNow: toPesewas(j['due_now']) ?? 0,
    totalPayable: toPesewas(j['total_payable']) ?? 0,
    numberOfPayments: (j['number_of_installments'] as num?)?.toInt() ?? 1,
    refundStatus: (j['refund_status'] ?? '').toString(),
    createdAt: parseApiDate(j['created_at']),
  );
}
