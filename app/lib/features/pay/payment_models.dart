import '../../core/format.dart';
import '../../core/paystack_checkout.dart';

/// What the Paystack checkout needs, as `POST /customer/payments/paystack/initialize`,
/// `POST /customer/purchase`, `POST /customer/orders/<id>/pay` and
/// `POST /customer/plans/<id>/deferment` return it.
class CheckoutStart {
  CheckoutStart({required this.reference, required this.authorizationUrl, required this.amount});
  final String reference;
  final Uri authorizationUrl;
  final int amount; // pesewas, what Paystack will charge

  /// Null when the response has no checkout page (Paystack off, or it couldn't be reached), or no
  /// amount to show the customer first (G18).
  static CheckoutStart? tryParse(Object? res) {
    if (res is! Map) return null;
    final ref = res['reference'];
    final url = res['authorization_url'];
    if (ref is! String || ref.isEmpty || url is! String || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !isPaystackCheckoutUrl(uri)) return null; // only Paystack's own checkout pages
    // G18: no amount, no checkout. The customer must always see what Paystack will charge.
    final amount = toPesewas(res['amount']);
    if (amount == null || amount <= 0) return null;
    return CheckoutStart(reference: ref, authorizationUrl: uri, amount: amount);
  }
}

/// How a payment ended, as the customer sees it.
enum PaymentState { paid, deferred, pending, failed, mismatch, refund, error }

/// `GET /customer/payments/paystack/verify/<reference>`. The app only says "paid" when the
/// server says the payment was applied.
class PaymentResult {
  PaymentResult({
    required this.reference,
    required this.purpose,
    required this.status,
    required this.outcome,
    required this.amount,
    required this.planId,
    required this.orderId,
    required this.installmentNumber,
  });

  final String reference;
  final String purpose; // instalment, plan_settlement, down_payment, deferment_fee
  final String status; // Paystack: success, failed, abandoned, pending...
  final String outcome; // applied, part, settled, overpaid, duplicate_payment, amount_mismatch, ...
  final int amount;
  final int? planId;
  final String? orderId;
  final int installmentNumber;

  bool get isDownPayment => purpose == 'down_payment';
  bool get isDeferment => purpose == 'deferment_fee';
  bool get isSettlement => purpose == 'plan_settlement';

  factory PaymentResult.fromJson(Map<String, dynamic> j) => PaymentResult(
    reference: (j['reference'] ?? '').toString(),
    purpose: (j['purpose'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    outcome: (j['outcome'] ?? '').toString(),
    amount: toPesewas(j['amount']) ?? 0,
    planId: (j['plan_id'] as num?)?.toInt(),
    orderId: j['order_id']?.toString(),
    installmentNumber: (j['installment_number'] as num?)?.toInt() ?? 1,
  );

  /// The web app's payment-callback rules, outcome by outcome.
  PaymentState get state {
    if (isDeferment && (outcome == 'deferred' || outcome == 'already_applied')) return PaymentState.deferred;
    switch (outcome) {
      case 'applied':
      case 'already_applied':
      case 'part':
      case 'settled':
      case 'overpaid':
      case 'duplicate_payment':
        return PaymentState.paid;
      case 'refund_required':
        return PaymentState.refund;
      case 'amount_mismatch':
      case 'reference_mismatch':
        return PaymentState.mismatch;
    }
    if (status == 'failed' || status == 'abandoned') return PaymentState.failed;
    return PaymentState.pending;
  }

  /// An extra line for some "paid" outcomes.
  String? get note => switch (outcome) {
    'part' => 'Part payment received. The rest of this payment is still due.',
    'settled' => 'Your plan is paid off. Thank you!',
    'overpaid' => 'This was more than was still owed, so we will review the extra for a refund.',
    'duplicate_payment' => 'This was already paid, so we will review this payment for a refund.',
    _ => null,
  };
}

/// One line of the pay-off quote.
class SettlementLine {
  SettlementLine({required this.number, required this.owed, required this.lateFee, required this.alreadyPaid});
  final int number;
  final int owed;
  final int lateFee;
  final int alreadyPaid;

  factory SettlementLine.fromJson(Map<String, dynamic> j) => SettlementLine(
    number: (j['installment_number'] as num?)?.toInt() ?? 0,
    owed: toPesewas(j['owed']) ?? 0,
    lateFee: toPesewas(j['late_fee']) ?? 0,
    alreadyPaid: toPesewas(j['already_paid']) ?? 0,
  );
}

/// `GET /customer/plans/<id>/settlement-quote`: every remaining payment and the total, shown
/// before the customer pays off a plan.
class SettlementQuote {
  SettlementQuote({required this.lines, required this.total, required this.note});
  final List<SettlementLine> lines;
  final int total;
  final String note;

  factory SettlementQuote.fromJson(Map<String, dynamic> j) => SettlementQuote(
    lines: ((j['instalments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SettlementLine.fromJson(e.cast<String, dynamic>()))
        .toList(),
    total: toPesewas(j['total']) ?? 0,
    note: (j['note'] ?? '').toString(),
  );
}
