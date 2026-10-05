import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/core/api_client.dart';
import 'package:tabital_pay/features/auth/auth_controller.dart';

import 'fake_api.dart';

void main() {
  test('signing in keeps the token and sends it with the device id', () async {
    final f = FakeApi({
      'POST /login': (200, {'access_token': 'tok-1'}),
      'GET /customer/dashboard/stats': (200, stats()),
    });
    await f.auth.signIn(' 0241234567 ', 'secret-password');

    expect(f.auth.status, AuthStatus.signedIn);
    expect(f.session.token, 'tok-1');
    expect(f.requests.first.body, contains('"phone":"0241234567"'));
    final check = f.requests[1];
    expect(check.headers['Authorization'], 'Bearer tok-1');
    expect(check.headers['X-Device-Id'], hasLength(32));
  });

  test("a wrong password shows the server's message", () async {
    final f = FakeApi({
      'POST /login': (401, {'error': 'Invalid phone or password'}),
    });
    await expectLater(
      f.auth.signIn('0241234567', 'x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid phone or password')),
    );
    expect(f.session.token, isNull);
  });

  test('merchant and admin accounts are sent to the website', () async {
    final f = FakeApi({
      'POST /login': (200, {'access_token': 'tok-m'}),
      'GET /customer/dashboard/stats': (403, {'error': 'Unauthorized'}),
    });
    await expectLater(f.auth.signIn('0201111111', 'pw'), throwsA(isA<ApiException>()));
    expect(f.session.token, isNull);
    expect(f.auth.status, isNot(AuthStatus.signedIn));
  });

  test('two-factor accounts (admins) are sent to the website', () async {
    final f = FakeApi({
      'POST /login': (200, {'two_factor_required': true, 'challenge': 'c'}),
    });
    await expectLater(f.auth.signIn('0201111111', 'pw'), throwsA(isA<ApiException>()));
    expect(f.session.token, isNull);
  });

  test('an expired session signs out with a notice', () async {
    final f = FakeApi({
      'POST /login': (200, {'access_token': 'tok-1'}),
      'GET /customer/dashboard/stats': (200, stats()),
      'GET /customer/instalments': (401, {'msg': 'Token expired'}),
    });
    await f.auth.signIn('0241234567', 'pw');
    await expectLater(f.customer.plans(), throwsA(isA<ApiException>()));

    expect(f.auth.status, AuthStatus.signedOut);
    expect(f.session.token, isNull);
    expect(f.auth.notice, isNotNull);
  });

  test('signing out keeps the device id', () async {
    final f = FakeApi({
      'POST /login': (200, {'access_token': 'tok-1'}),
      'GET /customer/dashboard/stats': (200, stats()),
    });
    await f.auth.signIn('0241234567', 'pw');
    final id = await f.session.deviceId();
    await f.auth.signOut();
    expect(f.session.token, isNull);
    expect(await f.session.deviceId(), id);
  });
}
