import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/features/pay/payment_models.dart';

import 'fake_api.dart';
import 'test_app.dart';

// The web app's payment-callback.money.spec.ts: "paid" only when the server applied the payment.
void main() {
  Map<String, dynamic> view(String outcome, [Map<String, dynamic> extra = const {}]) => {
    'reference': 'TBP-1',
    'purpose': 'instalment',
    'status': 'success',
    'outcome': outcome,
    'amount': 800.0,
    'plan_id': 7,
    'installment_number': 2,
    ...extra,
  };

  group('outcome rules', () {
    PaymentState state(String outcome, [Map<String, dynamic> extra = const {}]) =>
        PaymentResult.fromJson(view(outcome, extra)).state;

    test('applied, part, settled and already applied are paid', () {
      for (final o in ['applied', 'already_applied', 'part', 'settled']) {
        expect(state(o), PaymentState.paid, reason: o);
      }
    });
    test('money paid twice or above what was owed is paid, flagged for a refund review', () {
      expect(state('overpaid'), PaymentState.paid);
      expect(PaymentResult.fromJson(view('overpaid')).note, contains('refund'));
      expect(PaymentResult.fromJson(view('duplicate_payment')).note, contains('refund'));
    });
    test('never paid for an underpayment, a failure or an unconfirmed payment', () {
      expect(state('amount_mismatch'), PaymentState.mismatch);
      expect(state('reference_mismatch'), PaymentState.mismatch);
      expect(state('failed', {'status': 'failed'}), PaymentState.failed);
      expect(state('', {'status': 'abandoned'}), PaymentState.failed);
      expect(state('pending', {'status': 'pending'}), PaymentState.pending);
      expect(state('refund_required'), PaymentState.refund);
    });
    test('a deferment fee that went through moves the dates', () {
      expect(state('deferred', {'purpose': 'deferment_fee'}), PaymentState.deferred);
      expect(state('already_applied', {'purpose': 'deferment_fee'}), PaymentState.deferred);
    });
    test('only an https checkout page is opened', () {
      expect(CheckoutStart.tryParse(checkoutFixture()), isNotNull);
      expect(CheckoutStart.tryParse({...checkoutFixture(), 'authorization_url': 'http://evil.test/x'}), isNull);
      expect(CheckoutStart.tryParse({'message': 'Order submitted for approval'}), isNull);
    });
  });

  Future<FakeApi> land(WidgetTester tester, int status, Object body) async {
    final f = FakeApi({'GET /customer/payments/paystack/verify/TBP-1': (status, body)});
    await pumpApp(tester, f, '/payment-result/TBP-1');
    return f;
  }

  testWidgets('asks the server to verify, then confirms an applied payment', (tester) async {
    final f = await land(tester, 200, view('applied'));
    expect(calls(f, 'GET', '/customer/payments/paystack/verify/TBP-1'), 1);
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.textContaining('GHS 800.00 for payment 2'), findsOneWidget);
  });

  testWidgets('a part payment says the rest is still due', (tester) async {
    await land(tester, 200, view('part', {'amount': 300.0}));
    expect(find.textContaining('rest of this payment is still due'), findsOneWidget);
  });

  testWidgets('a plan paid off early', (tester) async {
    await land(tester, 200, view('settled', {'purpose': 'plan_settlement', 'amount': 1680.0}));
    expect(find.textContaining('GHS 1,680.00 to pay off your plan'), findsOneWidget);
    expect(find.text('Your plan is paid off. Thank you!'), findsOneWidget);
  });

  testWidgets('the down payment sends the order for approval', (tester) async {
    await land(tester, 200, view('applied', {'purpose': 'down_payment', 'amount': 1650.0, 'order_id': 'ORD-1', 'plan_id': null}));
    expect(find.text('Down payment received'), findsOneWidget);
    expect(find.textContaining('GHS 1,650.00 received for order ORD-1'), findsOneWidget);
    expect(find.text('View my order'), findsOneWidget);
  });

  testWidgets('a deferment fee moves the dates', (tester) async {
    await land(tester, 200, view('deferred', {'purpose': 'deferment_fee', 'amount': 80.0}));
    expect(find.text('Payment moved'), findsOneWidget);
    expect(find.textContaining('GHS 80.00 deferment fee'), findsOneWidget);
  });

  testWidgets('an underpayment is never shown as paid', (tester) async {
    await land(tester, 200, view('amount_mismatch'));
    expect(find.text('We need to check this payment'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);
  });

  testWidgets('a failed payment says no money was taken and offers a retry', (tester) async {
    await land(tester, 200, view('failed', {'status': 'failed'}));
    expect(find.textContaining('No money was taken'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets("a payment Paystack hasn't confirmed can be checked again", (tester) async {
    final f = await land(tester, 200, view('pending', {'status': 'pending'}));
    expect(find.text('Payment not confirmed yet'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(calls(f, 'GET', '/customer/payments/paystack/verify/TBP-1'), 2);
  });

  testWidgets("a verify error shows the server's message, not paid", (tester) async {
    await land(tester, 502, {'error': "Could not confirm the payment yet. We'll update it automatically."});
    expect(find.textContaining('Could not confirm the payment yet'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);
  });
}
