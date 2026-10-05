import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/features/shop/product_screen.dart';
import 'package:tabital_pay/features/shop/shop_models.dart';

import 'fake_api.dart';
import 'test_app.dart';

// The web app's shop.money.spec.ts. The §5.3 reference: GHS 4,000 phone, Pay in 4, 40% down,
// GHS 50 delivery with Payment 1 only. Every amount on screen is the server's quote.
void main() {
  FakeApi api({Map<String, dynamic>? options, String kyc = 'verified', (int, Object?)? purchase}) => FakeApi({
    'GET /customer/products': (
      200,
      {
        'products': [productFixture()],
        'total': 1,
        'page': 1,
        'total_pages': 1,
      },
    ),
    'GET /customer/products/categories': (
      200,
      {
        'categories': [
          {'name': 'Phones', 'count': 1},
        ],
      },
    ),
    'GET /customer/products/11': (200, productFixture()),
    'POST /customer/plan-options': (200, options ?? planOptionsFixture()),
    'GET /customer/identity': (200, identityFixture(kyc: kyc)),
    'GET /customer/credit': (200, planOptionsFixture()['credit']),
    'GET /customer/payments/config': (200, {'paystack_enabled': true}),
    'POST /customer/purchase':
        purchase ??
        (
          201,
          {
            'order_id': 'ORD-1',
            'id': 21,
            'status': 'awaiting_payment',
            'due_now': 1650.0,
            'total_payable': 4050.0,
            ...checkoutFixture(reference: 'TBP-ORD-1', amount: 1650),
            'message': 'Pay the down payment to send your order for approval',
          },
        ),
    'GET /customer/payments/paystack/verify/TBP-ORD-1': (
      200,
      {
        'reference': 'TBP-ORD-1',
        'purpose': 'down_payment',
        'status': 'success',
        'outcome': 'applied',
        'amount': 1650.0,
        'plan_id': null,
        'order_id': 'ORD-1',
        'installment_number': 1,
      },
    ),
  });

  bool enabled(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;
  String dueToday(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('due-today'))).data!;

  testWidgets("the shop shows the server's Pay in 4 teaser and the customer's limit", (tester) async {
    await pumpApp(tester, api(), '/shop');
    expect(find.text('Samsung Galaxy A55'), findsOneWidget);
    expect(find.text('GHS 4,000.00'), findsOneWidget);
    expect(find.text('GHS 1,600.00 today + delivery, then 3 × GHS 800.00'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('shop-limit'))).textSpan!.toPlainText(),
        'You can spend up to GHS 5,000.00 on a plan');
  });

  testWidgets('asks the server to price every plan and starts on Pay in 4 for an eligible customer', (tester) async {
    final f = api();
    await pumpApp(tester, f, '/shop/product/11');
    expect(lastBody(f, '/customer/plan-options'), {'product_id': 11, 'quantity': 1});
    expect(find.text('40% today, then 3 × GHS 800.00'), findsOneWidget);
    expect(dueToday(tester), 'GHS 1,650.00'); // 1,600 down + 50 delivery, from the server
    // The full schedule before checkout: Payment 1 with the delivery fee, then 3 × 800
    expect(find.text('Today · GHS 1,600.00 + GHS 50.00 delivery'), findsOneWidget);
    expect(find.text('3 Nov 2026'), findsOneWidget);
    expect(find.text('3 Jan 2027'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('schedule-total'))).data, 'GHS 4,050.00');
  });

  testWidgets('switching plans shows that plan, still priced by the server', (tester) async {
    await pumpApp(tester, api(), '/shop/product/11');
    await tester.tap(find.byKey(const Key('plan-2')));
    await tester.pumpAndSettle();
    expect(dueToday(tester), 'GHS 2,050.00');
    await tester.tap(find.byKey(const Key('plan-1')));
    await tester.pumpAndSettle();
    expect(dueToday(tester), 'GHS 4,050.00');
  });

  testWidgets('more than one: the server prices the new quantity', (tester) async {
    final f = api();
    await pumpApp(tester, f, '/shop/product/11');
    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();
    expect(lastBody(f, '/customer/plan-options'), {'product_id': 11, 'quantity': 2});
  });

  testWidgets("a plan the server blocks shows why and can't continue; paying in full still can", (tester) async {
    await pumpApp(tester, api(options: planOptionsFixture(availableLimit: 3000)), '/shop/product/11');
    expect(find.text('This is above your available limit'), findsWidgets);
    expect(enabled(tester, 'continue'), isFalse);
    await tester.tap(find.byKey(const Key('plan-1')));
    await tester.pumpAndSettle();
    expect(enabled(tester, 'continue'), isTrue);
  });

  testWidgets('a customer who is not eligible starts on paying in full', (tester) async {
    await pumpApp(tester, api(options: planOptionsFixture(eligible: false)), '/shop/product/11');
    expect(dueToday(tester), 'GHS 4,050.00');
    expect(enabled(tester, 'continue'), isTrue);
  });

  testWidgets("can't continue before identity is verified", (tester) async {
    await pumpApp(tester, api(kyc: 'pending'), '/shop/product/11');
    expect(find.text('Verify your identity before you buy.'), findsOneWidget);
    expect(enabled(tester, 'continue'), isFalse);
  });

  group('checkout', () {
    CheckoutArgs args() {
      final options = PlanOptions.fromJson(planOptionsFixture());
      return CheckoutArgs(product: Product.fromJson(productFixture()), options: options, option: options.option(4)!, quantity: 1);
    }

    Future<FakeApi> open(WidgetTester tester, {(int, Object?)? purchase, FakeCheckout? checkout}) async {
      final f = api(purchase: purchase);
      await pumpApp(tester, f, '/shop/product/11/checkout', extra: args(), checkout: checkout);
      return f;
    }

    testWidgets('shows Payment 1 with the delivery fee, the schedule, the total payable and the key facts', (tester) async {
      await open(tester);
      expect(tester.widget<Text>(find.byKey(const Key('due-now'))).data, 'GHS 1,650.00');
      expect(tester.widget<Text>(find.byKey(const Key('schedule-total'))).data, 'GHS 4,050.00');
      expect(find.text('Down payment (40%)'), findsOneWidget);
      expect(find.text('GHS 1,600.00'), findsOneWidget);
      expect(find.text('Delivery fee'), findsOneWidget);
      expect(find.text('GHS 800.00'), findsNWidgets(3)); // every monthly payment listed
      // The key facts use the server's settings, not numbers written into the app
      expect(find.textContaining('a late fee of 10% of it the day after the due date, and another 10% from 31 days'), findsOneWidget);
      expect(find.textContaining('never go above 25% of the total payable'), findsOneWidget);
      expect(find.textContaining('move one payment back 1 month for a 10% fee'), findsOneWidget);
      expect(find.textContaining('(21 days)'), findsOneWidget);
      expect(find.text('Pay GHS 1,650.00'), findsOneWidget);
    });

    testWidgets("won't order without accepting the terms or with a short address", (tester) async {
      final f = await open(tester);
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('place-order'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('agree')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('address')), 'Osu');
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 10 characters'), findsOneWidget);
      expect(calls(f, 'POST', '/customer/purchase'), 0);
    });

    testWidgets('sends only the choice (never an amount), once, and goes to Paystack for Payment 1', (tester) async {
      final checkout = FakeCheckout();
      final f = await open(tester, checkout: checkout);
      await tester.enterText(find.byKey(const Key('address')), 'Osu, Oxford Street, Accra');
      await tester.tap(find.byKey(const Key('agree')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.tap(find.byKey(const Key('place-order')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls(f, 'POST', '/customer/purchase'), 1);
      expect(lastBody(f, '/customer/purchase'), {
        'product_id': 11,
        'quantity': 1,
        'number_of_installments': 4,
        'delivery_address': 'Osu, Oxford Street, Accra',
        'accept_terms': true,
      });
      expect(checkout.opened.single.toString(), 'https://checkout.paystack.com/TBP-ORD-1');
      expect(find.text('Down payment received'), findsOneWidget);
    });

    testWidgets('shows why the server refused an order', (tester) async {
      final checkout = FakeCheckout();
      await open(
        tester,
        checkout: checkout,
        purchase: (
          403,
          {
            'error': "You're not eligible for a payment plan right now",
            'reasons': ['A payment is overdue'],
          },
        ),
      );
      await tester.enterText(find.byKey(const Key('address')), 'Osu, Oxford Street, Accra');
      await tester.tap(find.byKey(const Key('agree')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(find.textContaining('A payment is overdue'), findsOneWidget);
      expect(checkout.opened, isEmpty);
    });
  });

  group('orders', () {
    testWidgets('an order awaiting its down payment can be paid again', (tester) async {
      final f = FakeApi({
        'GET /customer/orders': (
          200,
          [
            {
              'id': 21,
              'order_id': 'ORD-1',
              'product_name': 'Samsung Galaxy A55',
              'status': 'awaiting_payment',
              'due_now': 1650.0,
              'total_payable': 4050.0,
              'number_of_installments': 4,
              'refund_status': null,
              'created_at': '2026-10-03T09:00:00',
            },
            {
              'id': 20,
              'order_id': 'ORD-0',
              'product_name': 'Fridge',
              'status': 'rejected',
              'due_now': 2000.0,
              'total_payable': 4000.0,
              'number_of_installments': 2,
              'refund_status': 'refunded',
              'created_at': '2026-09-01T09:00:00',
            },
          ],
        ),
        'POST /customer/orders/21/pay': (201, checkoutFixture(reference: 'TBP-ORD-1', amount: 1650)),
        'GET /customer/payments/paystack/verify/TBP-ORD-1': (
          200,
          {
            'reference': 'TBP-ORD-1',
            'purpose': 'down_payment',
            'status': 'success',
            'outcome': 'applied',
            'amount': 1650.0,
            'order_id': 'ORD-1',
            'installment_number': 1,
          },
        ),
      });
      final checkout = FakeCheckout();
      await pumpApp(tester, f, '/account/orders', checkout: checkout);
      expect(find.text('Awaiting down payment'), findsOneWidget);
      expect(find.text('Your down payment is being refunded'), findsOneWidget);
      await tester.tap(find.text('Pay GHS 1,650.00'));
      await tester.pumpAndSettle();
      expect(calls(f, 'POST', '/customer/orders/21/pay'), 1);
      expect(checkout.opened, hasLength(1));
      expect(find.text('Down payment received'), findsOneWidget);
    });
  });
}
