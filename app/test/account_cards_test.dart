import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/features/pay/payment_models.dart';

import 'fake_api.dart';
import 'test_app.dart';

// Batch C: saved cards and autopay (G8), the Account page (G10), and G18 (never open Paystack
// without an amount to show).
void main() {
  Map<String, dynamic> card(int id, {bool autopay = false, bool reusable = true, String last4 = '4081'}) => {
    'id': id,
    'channel': 'card',
    'card_type': 'visa ',
    'bank': 'GCB Bank',
    'last4': last4,
    'expiry': '12/2027',
    'reusable': reusable,
    'autopay_enabled': autopay,
    'is_default': autopay,
    'created_at': '2026-10-01T09:00:00',
  };

  group('G8: cards and autopay', () {
    FakeApi api(List<Map<String, dynamic>> cards) => FakeApi({
      'GET /customer/payment-methods': (200, {'payment_methods': cards}),
      'PUT /customer/payment-methods/3': (
        200,
        {'payment_method': card(3, autopay: true), 'message': "Autopay is on: we'll charge this card on each due date."},
      ),
      'DELETE /customer/payment-methods/3': (200, {'message': 'Card removed'}),
    });

    testWidgets('lists cards with their autopay state', (tester) async {
      await pumpApp(tester, api([card(3), card(4, autopay: true, last4: '1111')]), '/account/cards');
      expect(find.text('Visa •••• 4081'), findsOneWidget);
      expect(find.text('Visa •••• 1111'), findsOneWidget);
      expect(find.text('Autopay off'), findsOneWidget);
      expect(find.text('Autopay on'), findsOneWidget);
    });

    testWidgets('turning autopay on asks first, with the web wording; cancelling sends nothing', (tester) async {
      final f = api([card(3)]);
      await pumpApp(tester, f, '/account/cards');
      await tester.tap(find.byKey(const Key('autopay-3')));
      await tester.pumpAndSettle();
      expect(
        find.text("We'll charge card ending 4081 on each due date, and try again for a few days if a charge fails."),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls(f, 'PUT', '/customer/payment-methods/3'), 0);

      await tester.tap(find.byKey(const Key('autopay-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on autopay').last);
      await tester.pumpAndSettle();
      expect(lastBody(f, '/customer/payment-methods/3'), {'autopay_enabled': true});
      expect(find.text("Autopay is on: we'll charge this card on each due date."), findsOneWidget);
    });

    testWidgets('turning autopay off needs no confirm', (tester) async {
      final f = api([card(3, autopay: true)]);
      await pumpApp(tester, f, '/account/cards');
      await tester.tap(find.byKey(const Key('autopay-3')));
      await tester.pumpAndSettle();
      expect(lastBody(f, '/customer/payment-methods/3'), {'autopay_enabled': false});
    });

    testWidgets('a card Paystack can\'t charge again offers no autopay', (tester) async {
      await pumpApp(tester, api([card(3, reusable: false)]), '/account/cards');
      expect(find.byKey(const Key('autopay-3')), findsNothing);
      expect(find.text("This card can't be charged automatically."), findsOneWidget);
    });

    testWidgets('removing a card asks first, then removes it', (tester) async {
      final f = api([card(3)]);
      await pumpApp(tester, f, '/account/cards');
      await tester.tap(find.byKey(const Key('remove-3')));
      await tester.pumpAndSettle();
      expect(find.text('Remove card ending 4081?'), findsOneWidget);
      expect(find.text('Autopay will stop for this card.'), findsOneWidget);
      await tester.tap(find.text('Remove card'));
      await tester.pumpAndSettle();
      expect(calls(f, 'DELETE', '/customer/payment-methods/3'), 1);
    });

    testWidgets('the Pay screen lists saved cards under "Pay with"', (tester) async {
      final f = FakeApi({
        'GET /customer/instalments/7': (200, referencePlan()),
        'GET /customer/payments/config': (200, {'paystack_enabled': true}),
        'GET /customer/payment-methods': (
          200,
          {
            'payment_methods': [card(3, autopay: true)],
          },
        ),
      });
      await pumpApp(tester, f, '/plans/7/pay');
      expect(find.text('Visa •••• 4081'), findsOneWidget);
      expect(find.text('Autopay on'), findsOneWidget);
    });
  });

  group('G10: the Account page', () {
    FakeApi api({bool marketing = false}) => FakeApi({
      'GET /account/consents': (
        200,
        {
          'terms_version_accepted': '2026-10-03',
          'privacy_version_accepted': '2026-10-03',
          'accepted_at': '2026-10-03T10:00:00',
          'marketing_consent': marketing,
          'marketing_consent_at': null,
        },
      ),
      'PUT /account/consents': (200, {'marketing_consent': true, 'message': "You'll get offers and news from Tabital Pay."}),
    });

    testWidgets('Help, the support contact, the Terms version from the server and the legal line', (tester) async {
      await pumpApp(tester, api(), '/account');
      expect(find.byKey(const Key('account-help')), findsOneWidget);
      expect(find.text('info@tabitalpay.com'), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const Key('account-terms-version'))).data,
        'You accepted the Terms version 2026-10-03 on 3 Oct 2026.',
      );
      expect(tester.widget<Text>(find.byKey(const Key('account-legal'))).data, 'Tabital Pay Ltd · Registration CS 117960626');
      expect(find.byKey(const Key('account-cards')), findsOneWidget);
    });

    testWidgets('offers and news can be turned on; reminders are unaffected', (tester) async {
      final f = api();
      await pumpApp(tester, f, '/account');
      expect(find.text('Payment reminders and receipts come either way.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-marketing')));
      await tester.pumpAndSettle();
      expect(lastBody(f, '/account/consents'), {'marketing_consent': true});
    });

    testWidgets('without the consents the page still works', (tester) async {
      await pumpApp(tester, FakeApi({}), '/account');
      expect(find.byKey(const Key('account-terms-version')), findsNothing);
      expect(find.byKey(const Key('account-legal')), findsOneWidget);
    });
  });

  group('G18: no amount, no checkout', () {
    test('a checkout link with no amount, or zero, is refused', () {
      expect(CheckoutStart.tryParse({...checkoutFixture()}..remove('amount')), isNull);
      expect(CheckoutStart.tryParse({...checkoutFixture(), 'amount': 0}), isNull);
      expect(CheckoutStart.tryParse({...checkoutFixture(), 'amount': 'abc'}), isNull);
      expect(CheckoutStart.tryParse(checkoutFixture())!.amount, 88000);
    });

    testWidgets('the Pay screen shows an error and never opens Paystack', (tester) async {
      final checkout = FakeCheckout();
      final f = FakeApi({
        'GET /customer/instalments/7': (200, referencePlan()),
        'GET /customer/payments/config': (200, {'paystack_enabled': true}),
        'POST /customer/payments/paystack/initialize': (201, {...checkoutFixture()}..remove('amount')),
      });
      await pumpApp(tester, f, '/plans/7/pay', checkout: checkout);
      await tester.tap(find.byKey(const Key('pay-button')));
      await tester.pumpAndSettle();
      expect(find.text('Could not start the payment. Please try again.'), findsOneWidget);
      expect(checkout.opened, isEmpty);
    });
  });
}
