import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';
import 'test_app.dart';

// The deferment disclosure (§4, web customer-instalments.money.spec.ts): fee, new dates and new
// total from the server, shown before the customer agrees. The fee is paid through Paystack.
void main() {
  const path = '/customer/plans/7/deferment';
  Map<String, dynamic> quote({bool allowed = true, bool online = true}) => {
    'allowed': allowed,
    'reasons': allowed ? <String>[] : ['A payment on this plan is overdue', 'Pay it first, then you can move a payment'],
    'plan_id': 7,
    'payment_id': 3,
    'installment_number': 3,
    'instalment_amount': 800.0,
    'fee_base': 800.0,
    'fee': 80.0,
    'fee_percentage': 10.0,
    'months': 1,
    'deferments_left': 1,
    'schedule': [
      {'payment_id': 3, 'installment_number': 3, 'amount': 800.0, 'due_date': '2026-11-03', 'new_due_date': '2026-12-03'},
      {'payment_id': 4, 'installment_number': 4, 'amount': 800.0, 'due_date': '2026-12-03', 'new_due_date': '2027-01-03'},
    ],
    'total_payable_before': 4050.0,
    'total_payable_after': 4130.0,
    'history': [],
    'online_payment': online,
  };

  FakeApi api({Map<String, dynamic>? q}) => FakeApi({
    'GET $path': (200, q ?? quote()),
    'POST $path': (201, checkoutFixture(reference: 'TBP-DEF-1', amount: 80)),
    'GET /customer/payments/paystack/verify/TBP-DEF-1': (
      200,
      {
        'reference': 'TBP-DEF-1',
        'purpose': 'deferment_fee',
        'status': 'success',
        'outcome': 'deferred',
        'amount': 80.0,
        'plan_id': 7,
        'installment_number': 3,
      },
    ),
  });

  bool enabled(WidgetTester tester) => tester.widget<ButtonStyleButton>(find.byKey(const Key('defer-button'))).onPressed != null;

  testWidgets('shows the fee, its basis, every moved date and the new total from the server', (tester) async {
    final f = api();
    await pumpApp(tester, f, '/plans/7/defer?payment=3');
    expect(f.requests.lastWhere((r) => r.url.path == path).url.queryParameters['payment_id'], '3');
    expect(tester.widget<Text>(find.byKey(const Key('defer-fee'))).data, 'GHS 80.00');
    expect(tester.widget<Text>(find.byKey(const Key('defer-fee-basis'))).data, '10% of the GHS 800.00 left on payment 3');
    String rich(String key) => tester.widget<Text>(find.byKey(Key(key))).textSpan!.toPlainText();
    expect(rich('defer-move-3'), '3 Nov 2026 → 3 Dec 2026'); // the old date is struck through
    expect(rich('defer-move-4'), '3 Dec 2026 → 3 Jan 2027');
    expect(rich('defer-totals'), 'GHS 4,050.00 → GHS 4,130.00');
  });

  testWidgets("can't pay until the customer agrees; then only the payment and consent are sent", (tester) async {
    final f = api();
    final checkout = FakeCheckout();
    await pumpApp(tester, f, '/plans/7/defer?payment=3', checkout: checkout);
    expect(enabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('defer-agree')));
    await tester.pump();
    expect(enabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('defer-button')));
    await tester.pumpAndSettle();
    expect(lastBody(f, path), {'payment_id': 3, 'agree': true});
    expect(checkout.opened.single.toString(), 'https://checkout.paystack.com/TBP-DEF-1');
    expect(find.text('Payment moved'), findsOneWidget);
  });

  testWidgets("when the server says no, it shows why and offers nothing to pay", (tester) async {
    await pumpApp(tester, api(q: quote(allowed: false)), '/plans/7/defer?payment=3');
    expect(find.textContaining('A payment on this plan is overdue'), findsOneWidget);
    expect(find.byKey(const Key('defer-button')), findsNothing);
  });

  testWidgets("with online payment off, the fee can't be paid", (tester) async {
    await pumpApp(tester, api(q: quote(online: false)), '/plans/7/defer?payment=3');
    await tester.tap(find.byKey(const Key('defer-agree')));
    await tester.pump();
    expect(enabled(tester), isFalse);
  });
}
