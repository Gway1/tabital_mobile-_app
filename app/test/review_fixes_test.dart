import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabital_pay/core/api_client.dart';
import 'package:tabital_pay/core/secure_store.dart';
import 'package:tabital_pay/features/auth/auth_controller.dart';
import 'package:tabital_pay/ui/theme.dart';
import 'package:tabital_pay/ui/vault.dart';

import 'fake_api.dart';
import 'test_app.dart';

// The standing reviewer's round-1 items: X2 (D12), A2 (account_inactive), A3 (device flags),
// A4 (no reference), D5 (48 dp agree rows).
void main() {
  testWidgets('X2 (D12): 6- and 12-month plans show "coming soon" and can\'t be chosen', (tester) async {
    final f = FakeApi({
      'GET /customer/products/11': (200, productFixture()),
      'POST /customer/plan-options': (200, planOptionsFixture()),
      'GET /customer/identity': (200, identityFixture()),
    });
    await pumpApp(tester, f, '/shop/product/11');
    expect(find.text('6 and 12 months'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    final before = calls(f, 'POST', '/customer/plan-options');
    await tester.tap(find.text('6 and 12 months'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('due-today'))).data, 'GHS 1,650.00'); // still Pay in 4
    expect(calls(f, 'POST', '/customer/plan-options'), before); // nothing asked of the server
  });

  test("A2: a suspended account is told so, in the web app's words", () async {
    final f = FakeApi({
      'POST /login': (200, {'access_token': 'tok-1'}),
      'GET /customer/dashboard/stats': (200, stats()),
      'GET /customer/instalments': (
        401,
        {'error': "Your account isn't active. Please contact Tabital.", 'code': 'account_inactive'},
      ),
    });
    await f.auth.signIn('0241234567', 'secret-password');
    await expectLater(f.customer.plans(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'account_inactive')));
    expect(f.auth.status, AuthStatus.signedOut);
    expect(f.auth.notice, "Your account isn't active any more. Please contact Tabital.");
  });

  test('A2: an expired session keeps the usual message', () async {
    final f = FakeApi({
      'POST /login': (200, {'access_token': 'tok-1'}),
      'GET /customer/dashboard/stats': (200, stats()),
      'GET /customer/instalments': (401, {'error': 'Signature has expired'}),
    });
    await f.auth.signIn('0241234567', 'secret-password');
    await expectLater(f.customer.plans(), throwsA(isA<ApiException>()));
    expect(f.auth.notice, contains('signed out to keep your account safe'));
  });

  test('A3: the emulator flag goes to our API with every request; none on a phone', () async {
    final seen = <http.BaseRequest>[];
    ApiClient client(String? flags) => ApiClient(
      baseUrl: 'https://api.test',
      session: SessionStore(MemoryStore()),
      client: MockClient((req) async {
        seen.add(req);
        return http.Response(jsonEncode({}), 200);
      }),
    )..deviceFlags = flags;
    await client('emulator').get('/customer/products');
    await client('').get('/customer/products');
    expect(seen[0].headers['X-Device-Flags'], 'emulator');
    expect(seen[1].headers.containsKey('X-Device-Flags'), isFalse);
  });

  testWidgets('A4: with no payment reference, nothing is asked of the server', (tester) async {
    final f = FakeApi({});
    await pumpApp(tester, f, '/payment-result/%20');
    expect(find.text('No payment reference was returned.'), findsOneWidget);
    expect(f.requests.where((r) => r.url.path.contains('/verify/')), isEmpty);
  });

  testWidgets('D5: the agree row is a 48 dp target, and tapping its sentence ticks the box', (tester) async {
    var agreed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(googleFonts: false),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CheckRow(
              boxKey: const Key('box'),
              value: agreed,
              onChanged: (v) => setState(() => agreed = v),
              child: const Text('I agree to the payment schedule above.'),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(CheckRow)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byKey(const Key('box'))).width, greaterThanOrEqualTo(48));
    await tester.tap(find.text('I agree to the payment schedule above.'));
    await tester.pump();
    expect(agreed, isTrue);
  });
}
