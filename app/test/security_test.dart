import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/core/paystack_checkout.dart';
import 'package:tabital_pay/core/secure_window.dart';
import 'package:tabital_pay/features/auth/welcome_screen.dart';
import 'package:tabital_pay/features/pay/payment_models.dart';
import 'package:tabital_pay/ui/theme.dart';
import 'package:tabital_pay/ui/widgets.dart';

import 'fake_api.dart';

void main() {
  group('M2: hidden from screenshots and the app switcher', () {
    test('payment, plan, checkout, result, identity and account screens', () {
      for (final path in [
        '/plans/7',
        '/plans/7/pay',
        '/plans/7/defer',
        '/payment-result/TBP-1',
        '/shop/product/11/checkout',
        '/account',
        '/account/orders',
        '/account/identity',
        '/account/limit',
      ]) {
        expect(isSecureLocation(path), isTrue, reason: path);
      }
    });

    test('screens without personal figures stay normal', () {
      for (final path in ['/welcome', '/sign-in', '/sign-up', '/shop', '/shop/product/11', '/plans', '/home']) {
        expect(isSecureLocation(path), isFalse, reason: path);
      }
    });

    testWidgets('the flag is sent to Android only when it changes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <Object?>[];
      const channel = MethodChannel('test/secure');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.arguments);
        return call.arguments;
      });
      final w = SecureWindow(channel: channel);
      await w.forLocation('/plans/7');
      await w.forLocation('/plans/7/pay');
      await w.forLocation('/shop');
      expect(calls, [true, false]);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('M4: the Paystack window', () {
    test('checkout only starts on Paystack\'s own https pages', () {
      expect(isPaystackCheckoutUrl(Uri.parse('https://checkout.paystack.com/abc')), isTrue);
      expect(isPaystackCheckoutUrl(Uri.parse('https://paystack.co/pay/x')), isTrue);
      expect(isPaystackCheckoutUrl(Uri.parse('http://checkout.paystack.com/abc')), isFalse);
      expect(isPaystackCheckoutUrl(Uri.parse('https://paystack.com.evil.test/abc')), isFalse);
      expect(isPaystackCheckoutUrl(Uri.parse('https://evilpaystack.com/abc')), isFalse);
      expect(CheckoutStart.tryParse({...checkoutFixture(), 'authorization_url': 'https://pay.example.com/x'}), isNull);
    });

    test('plain http never loads; bank and USSD links leave the app; scripts are blocked', () {
      expect(checkoutNavigation('https://checkout.paystack.com/abc'), CheckoutNav.allow);
      expect(checkoutNavigation('https://3ds.somebank.com.gh/challenge'), CheckoutNav.allow); // a bank's card check
      expect(checkoutNavigation('http://checkout.paystack.com/abc'), CheckoutNav.block);
      expect(checkoutNavigation('http://localhost:4200/customer/payment-callback?reference=TBP-1'), CheckoutNav.callback);
      expect(checkoutNavigation('https://app.tabitalpay.com/customer/payment-callback?trxref=TBP-1'), CheckoutNav.callback);
      expect(checkoutNavigation('tel:*170#'), CheckoutNav.external);
      expect(checkoutNavigation('intent://pay#Intent;scheme=momo;end'), CheckoutNav.external);
      expect(checkoutNavigation('javascript:alert(1)'), CheckoutNav.block);
      expect(checkoutNavigation('file:///sdcard/x.html'), CheckoutNav.block);
      expect(checkoutNavigation('data:text/html,hi'), CheckoutNav.block);
    });
  });

  group('sign in', () {
    test('a phone typed with spaces, as the hint shows it, is sent without them', () async {
      final f = FakeApi({
        'POST /login': (200, {'access_token': 'tok-1'}),
        'GET /customer/dashboard/stats': (200, stats()),
      });
      await f.auth.signIn(' 024 123 4567 ', 'secret-password');
      expect(f.requests.first.body, contains('"phone":"0241234567"'));
    });

    test('an email is sent as typed', () async {
      final f = FakeApi({
        'POST /login': (200, {'access_token': 'tok-1'}),
        'GET /customer/dashboard/stats': (200, stats()),
      });
      await f.auth.signIn(' ama-m@example.com ', 'secret-password');
      expect(f.requests.first.body, contains('"phone":"ama-m@example.com"'));
    });
  });

  group('M14: the real logo', () {
    testWidgets('Welcome shows the Tabital mark and name, not a placeholder', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: buildTheme(googleFonts: false), home: const WelcomeScreen()));
      final mark = find.byType(TabitalMark);
      expect(mark, findsOneWidget);
      expect(find.descendant(of: mark, matching: find.byType(Image)), findsOneWidget);
      expect(tester.widget<Image>(find.descendant(of: mark, matching: find.byType(Image))).image,
          isA<AssetImage>().having((a) => a.assetName, 'asset', 'assets/brand/mark.png'));
      expect(find.bySemanticsLabel('Tabital Pay'), findsWidgets);
    });
  });
}
