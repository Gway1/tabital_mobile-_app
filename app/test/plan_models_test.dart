import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/features/plans/plan_models.dart';

import 'fake_api.dart';

void main() {
  test('reads the §5.3 plan exactly as the server sent it', () {
    final p = Plan.fromJson(referencePlan());
    expect(p.totalAmount, 400000);
    expect(p.amountOutstanding, 240000);
    expect(p.schedule.map((s) => s.amount), [160000, 80000, 80000, 80000]);
    expect(p.schedule[1].lateFee, 8000);
    expect(p.schedule[1].amountDue, 88000);
    expect(p.paidCount, 1);
  });

  test('next due is the earliest unpaid payment, overdue included', () {
    final next = findNextDue([Plan.fromJson(referencePlan())])!;
    expect(next.payment.number, 2);
    expect(next.payment.amountDue, 88000);
    expect(next.overdue(DateTime(2026, 10, 3)), isTrue);
  });

  test('a payment past its date counts as overdue even before the server marks it', () {
    final next = findNextDue([Plan.fromJson(referencePlan(secondStatus: 'pending', lateFee: 0))])!;
    expect(next.overdue(DateTime(2026, 9, 30)), isFalse);
    expect(next.overdue(DateTime(2026, 10, 2)), isTrue);
  });

  test('completed and cancelled plans never lead Home', () {
    final done = referencePlan()..['status'] = 'completed';
    final cancelled = referencePlan()..['status'] = 'cancelled';
    expect(findNextDue([Plan.fromJson(done), Plan.fromJson(cancelled)]), isNull);
  });

  test('picks across plans', () {
    final later = referencePlan(secondStatus: 'paid', lateFee: 0)..['id'] = 8;
    final next = findNextDue([Plan.fromJson(later), Plan.fromJson(referencePlan())])!;
    expect(next.plan.id, 7);
  });
}
