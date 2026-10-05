import '../../core/format.dart';

/// One payment in a plan's schedule, as `GET /customer/instalments` returns it.
/// Amounts are kept in pesewas exactly as the server sent them; the app never works them out.
class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.number,
    required this.dueDate,
    required this.amount,
    required this.lateFee,
    required this.amountDue,
    required this.partPaid,
    required this.status,
    this.originalDueDate,
    this.paidDate,
  });

  final int id;
  final int number;
  final DateTime? dueDate;
  final DateTime? originalDueDate;
  final int amount; // the instalment
  final int lateFee; // unpaid late fee
  final int amountDue; // what's owed now (instalment + unpaid late fee - part payments)
  final int partPaid;
  final String status; // pending, overdue, paid
  final DateTime? paidDate;

  bool get unpaid => status == 'pending' || status == 'overdue';
  bool get paid => status == 'paid';

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: ((j['installment_number'] ?? j['instalment_number']) as num?)?.toInt() ?? 0,
    dueDate: parseApiDate(j['due_date']),
    originalDueDate: parseApiDate(j['original_due_date']),
    amount: toPesewas(j['amount']) ?? 0,
    lateFee: toPesewas(j['late_fee']) ?? 0,
    amountDue: toPesewas(j['amount_due']) ?? 0,
    partPaid: toPesewas(j['part_paid']) ?? 0,
    status: (j['status'] ?? '').toString(),
    paidDate: parseApiDate(j['paid_date']),
  );
}

/// A customer's plan, from `GET /customer/instalments`.
class Plan {
  Plan({
    required this.id,
    required this.planRef,
    required this.productName,
    required this.merchantName,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountOutstanding,
    required this.status,
    required this.schedule,
  });

  final int id;
  final String planRef;
  final String productName;
  final String merchantName;
  final int totalAmount;
  final int amountPaid;
  final int amountOutstanding;
  final String status; // active, completed, defaulted, cancelled
  final List<ScheduleItem> schedule;

  int get paidCount => schedule.where((p) => p.paid).length;

  /// Plans the customer still owes on.
  bool get open => status == 'active' || status == 'defaulted';

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    id: (j['id'] as num?)?.toInt() ?? 0,
    planRef: (j['plan_id'] ?? '').toString(),
    productName: (j['product_name'] ?? '').toString(),
    merchantName: (j['merchant_name'] ?? '').toString(),
    totalAmount: toPesewas(j['total_amount']) ?? 0,
    amountPaid: toPesewas(j['amount_paid']) ?? 0,
    amountOutstanding: toPesewas(j['amount_outstanding']) ?? 0,
    status: (j['status'] ?? '').toString(),
    schedule:
        ((j['payment_schedule'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ScheduleItem.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number)),
  );
}

/// The payment that leads the Home screen.
class NextDue {
  NextDue(this.plan, this.payment);
  final Plan plan;
  final ScheduleItem payment;

  /// Overdue when the server says so, or when the due date has passed.
  bool overdue(DateTime today) =>
      payment.status == 'overdue' || (payment.dueDate != null && daysUntil(payment.dueDate!, today) < 0);
}

/// The earliest unpaid payment across the customer's open plans (the web app's rule).
NextDue? findNextDue(Iterable<Plan> plans) {
  NextDue? best;
  for (final plan in plans.where((p) => p.open)) {
    for (final pay in plan.schedule.where((s) => s.unpaid && s.dueDate != null)) {
      if (best == null || pay.dueDate!.isBefore(best.payment.dueDate!)) best = NextDue(plan, pay);
    }
  }
  return best;
}

/// The spending limit from underwriting (`credit` in `GET /customer/dashboard/stats`).
class CreditSummary {
  CreditSummary({
    required this.eligible,
    required this.tier,
    required this.creditLimit,
    required this.availableLimit,
    required this.reasons,
  });

  final bool eligible;
  final String tier;
  final int creditLimit;
  final int availableLimit;
  final List<String> reasons;

  factory CreditSummary.fromJson(Map<String, dynamic> j) => CreditSummary(
    eligible: j['eligible'] == true,
    tier: (j['tier'] ?? '').toString(),
    creditLimit: toPesewas(j['credit_limit']) ?? 0,
    availableLimit: toPesewas(j['available_limit']) ?? 0,
    reasons: ((j['reasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
  );
}
