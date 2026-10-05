import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';
import 'test_app.dart';

// The web app's make-payment.money.spec.ts: the amount always comes from the server; the customer
// can pay the next payment, part of it, or everything left on the plan (R5).
void main() {
  const init = '/customer/payments/paystack/initialize';
  const settlementQuote = {
    'plan_id': 7,
    'total': 1680.0,
    'currency': 'GHS',
    'early_settlement_fee': 0.0,
    'note': 'No extra charge for paying early: your plan is interest-free.',
    'instalments': [
      {'installment_number': 2, 'owed': 880.0, 'late_fee': 80.0, 'already_paid': 0.0},
      {'installment_number': 3, 'owed': 800.0, 'late_fee': 0.0, 'already_paid': 0.0},
    ],
  };

  FakeApi api({bool paystack = true, (int, Object?)? start, (int, Object?)? quote}) => FakeApi({
    'GET /customer/instalments/7': (200, referencePlan()),
    'GET /customer/payments/config': (200, {'paystack_enabled': paystack}),
    'POST $init': start ?? (201, checkoutFixture()),
    'GET /customer/plans/7/settlement-quote': quote ?? (200, settlementQuote),
    'GET /customer/payments/paystack/verify/TBP-7-2-abc': (
      200,
      {
        'reference': 'TBP-7-2-abc',
        'purpose': 'instalment',
        'status': 'success',
        'outcome': 'applied',
        'amount': 880.0,
        'plan_id': 7,
        'installment_number': 2,
      },
    ),
  });

  String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
  bool enabled(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

  testWidgets('shows what the server says is due: the payment and its late fee as its own line', (tester) async {
    await pumpApp(tester, api(), '/plans/7/pay');
    expect(textOf(tester, 'pay-due'), 'GHS 880.00');
    expect(textOf(tester, 'pay-late-fee'), 'GHS 80.00');
    expect(find.text('Pay GHS 880.00'), findsOneWidget);
  });

  testWidgets('pays the next payment: only the plan is sent, then Paystack, then the server verifies', (tester) async {
    final f = api();
    final checkout = FakeCheckout();
    await pumpApp(tester, f, '/plans/7/pay', checkout: checkout);
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pumpAndSettle();

    expect(lastBody(f, init), {'plan_id': 7});
    expect(checkout.opened.single.toString(), 'https://checkout.paystack.com/TBP-7-2-abc');
    expect(calls(f, 'GET', '/customer/payments/paystack/verify/TBP-7-2-abc'), 1);
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.textContaining('GHS 880.00 for payment 2 has been received'), findsOneWidget);
  });

  testWidgets('pays part of a payment, sending the typed amount exactly', (tester) async {
    final f = api(start: (201, checkoutFixture(amount: 300.50)));
    await pumpApp(tester, f, '/plans/7/pay');
    await tester.tap(find.text('Pay part'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('part-amount')), '300.50');
    await tester.pump();
    expect(find.text('Pay GHS 300.50'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pumpAndSettle();
    expect(lastBody(f, init), {'plan_id': 7, 'amount': '300.50'});
  });

  testWidgets("won't start a part payment above what's due, or of nothing", (tester) async {
    final f = api();
    await pumpApp(tester, f, '/plans/7/pay');
    await tester.tap(find.text('Pay part'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('part-amount')), '900');
    await tester.pump();
    expect(find.textContaining('pay off the whole plan'), findsOneWidget);
    expect(enabled(tester, 'pay-button'), isFalse);

    await tester.enterText(find.byKey(const Key('part-amount')), '0');
    await tester.pump();
    expect(enabled(tester, 'pay-button'), isFalse);
    expect(calls(f, 'POST', init), 0);
  });

  testWidgets('pays off the plan: every remaining payment and the total first', (tester) async {
    final f = api(start: (201, checkoutFixture(amount: 1680)));
    await pumpApp(tester, f, '/plans/7/pay');
    await tester.tap(find.text('Pay off plan'));
    await tester.pumpAndSettle();
    expect(find.text('Payment 3'), findsOneWidget); // payment 2 is also in the summary above
    expect(find.text('includes GHS 80.00 late fee'), findsOneWidget);
    expect(textOf(tester, 'settle-total'), 'GHS 1,680.00');
    expect(find.text('Pay GHS 1,680.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pumpAndSettle();
    expect(lastBody(f, init), {'plan_id': 7, 'settle': true});
  });

  testWidgets("doesn't offer pay-off when the quote can't be loaded", (tester) async {
    await pumpApp(tester, api(quote: (404, {'error': 'Instalment plan not found'})), '/plans/7/pay');
    await tester.tap(find.text('Pay off plan'));
    await tester.pumpAndSettle();
    expect(find.text('Instalment plan not found'), findsOneWidget);
    expect(enabled(tester, 'pay-button'), isFalse);
  });

  testWidgets('starts one checkout on a double tap, and shows the server error', (tester) async {
    final f = api(start: (400, {'error': 'No payments due on this plan'}));
    final checkout = FakeCheckout();
    await pumpApp(tester, f, '/plans/7/pay', checkout: checkout);
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.tap(find.byKey(const Key('pay-button')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(calls(f, 'POST', init), 1);
    expect(find.text('No payments due on this plan'), findsOneWidget);
    expect(checkout.opened, isEmpty);
  });

  testWidgets('with online payment off, nothing can be started', (tester) async {
    await pumpApp(tester, api(paystack: false), '/plans/7/pay');
    expect(find.textContaining("Online payment isn't available"), findsOneWidget);
    expect(enabled(tester, 'pay-button'), isFalse);
  });

  // CLAUDE.md §12: the customer pays the amount they agreed to, or agrees again to the new one
  testWidgets('if the server now charges more, the customer must agree again before Paystack opens', (tester) async {
    final f = api(start: (201, checkoutFixture(amount: 960)));
    final checkout = FakeCheckout();
    await pumpApp(tester, f, '/plans/7/pay', checkout: checkout);
    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // the button's spinner never settles
    expect(find.byKey(const Key('amount-changed')), findsOneWidget);
    expect(find.textContaining('You agreed to pay GHS 880.00. Paystack will now charge GHS 960.00'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(checkout.opened, isEmpty);

    await tester.tap(find.byKey(const Key('pay-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Pay GHS 960.00'));
    await tester.pumpAndSettle();
    expect(checkout.opened, hasLength(1));
  });
}
