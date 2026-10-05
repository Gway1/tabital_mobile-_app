import '../../core/format.dart';

/// A payment the deferment moves: its old and new due dates.
class MovedPayment {
  MovedPayment({required this.number, required this.amount, required this.dueDate, required this.newDueDate});
  final int number;
  final int amount;
  final DateTime? dueDate;
  final DateTime? newDueDate;

  factory MovedPayment.fromJson(Map<String, dynamic> j) => MovedPayment(
    number: (j['installment_number'] as num?)?.toInt() ?? 0,
    amount: toPesewas(j['amount']) ?? 0,
    dueDate: parseApiDate(j['due_date']),
    newDueDate: parseApiDate(j['new_due_date']),
  );
}

/// `GET /customer/plans/<id>/deferment`: the fee, the new dates and the new total, shown
/// before the customer agrees (§4). The server decides whether deferring is allowed.
class DefermentQuote {
  DefermentQuote({
    required this.allowed,
    required this.reasons,
    required this.paymentId,
    required this.installmentNumber,
    required this.feeBase,
    required this.fee,
    required this.feePercentage,
    required this.months,
    required this.defermentsLeft,
    required this.moved,
    required this.totalBefore,
    required this.totalAfter,
    required this.onlinePayment,
  });

  final bool allowed;
  final List<String> reasons;
  final int? paymentId;
  final int? installmentNumber;
  final int feeBase; // what's still owed on the instalment
  final int fee;
  final String feePercentage; // as the server sent it, for display only
  final int months;
  final int defermentsLeft;
  final List<MovedPayment> moved;
  final int totalBefore;
  final int totalAfter;
  final bool onlinePayment;

  factory DefermentQuote.fromJson(Map<String, dynamic> j) {
    final pct = j['fee_percentage'];
    return DefermentQuote(
      allowed: j['allowed'] == true,
      reasons: ((j['reasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
      paymentId: (j['payment_id'] as num?)?.toInt(),
      installmentNumber: (j['installment_number'] as num?)?.toInt(),
      feeBase: toPesewas(j['fee_base']) ?? 0,
      fee: toPesewas(j['fee']) ?? 0,
      feePercentage: pct is num ? (pct == pct.roundToDouble() ? pct.toInt().toString() : pct.toString()) : '',
      months: (j['months'] as num?)?.toInt() ?? 1,
      defermentsLeft: (j['deferments_left'] as num?)?.toInt() ?? 0,
      moved: ((j['schedule'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MovedPayment.fromJson(e.cast<String, dynamic>()))
          .toList(),
      totalBefore: toPesewas(j['total_payable_before']) ?? 0,
      totalAfter: toPesewas(j['total_payable_after']) ?? 0,
      onlinePayment: j['online_payment'] == true,
    );
  }
}
