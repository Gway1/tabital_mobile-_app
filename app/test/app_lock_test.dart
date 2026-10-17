import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/app.dart';
import 'package:tabital_pay/core/app_lock.dart';
import 'package:tabital_pay/features/auth/auth_controller.dart';

import 'fake_api.dart';

/// The phone's lock, faked.
class FakeDeviceAuth implements DeviceAuth {
  FakeDeviceAuth({this.has = true, this.answers = const [true]});
  final bool has;
  final List<bool> answers;
  int prompts = 0;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> unlock(String reason) async => answers[prompts++ % answers.length];
}

// G9: app lock after 5 minutes in the background (design brief §7)
void main() {
  group('when it locks', () {
    test('a saved session opens locked when the phone has a lock', () async {
      final lock = AppLock(device: FakeDeviceAuth());
      await lock.lockOnStart();
      expect(lock.locked, isTrue);
    });

    test("a phone with no screen lock can't be asked, so the app doesn't lock", () async {
      final lock = AppLock(device: FakeDeviceAuth(has: false));
      await lock.lockOnStart();
      expect(lock.locked, isFalse);
    });

    test('under 5 minutes away stays open; 5 minutes or more locks', () async {
      var now = DateTime(2026, 10, 6, 9);
      final lock = AppLock(device: FakeDeviceAuth(), clock: () => now);
      lock.paused();
      now = now.add(const Duration(minutes: 4, seconds: 59));
      await lock.resumed();
      expect(lock.locked, isFalse);

      lock.paused();
      now = now.add(const Duration(minutes: 5));
      await lock.resumed();
      expect(lock.locked, isTrue);
    });

    test('unlocking with the phone opens it; a failed attempt keeps it locked', () async {
      final lock = AppLock(device: FakeDeviceAuth(answers: [false, true]));
      await lock.lockOnStart();
      expect(await lock.unlock(), isFalse);
      expect(lock.locked, isTrue);
      expect(await lock.unlock(), isTrue);
      expect(lock.locked, isFalse);
    });
  });

  group('the lock screen', () {
    Future<(FakeApi, FakeDeviceAuth)> open(WidgetTester tester, {List<bool> answers = const [false]}) async {
      tester.view.physicalSize = const Size(430 * 3, 932 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final f = FakeApi({
        'GET /customer/dashboard/stats': (200, stats()),
        'GET /customer/instalments': (
          200,
          {
            'plans': [referencePlan()],
          },
        ),
      });
      f.auth.status = AuthStatus.signedIn;
      final device = FakeDeviceAuth(answers: answers);
      final lock = AppLock(device: device);
      await lock.lockOnStart();
      await tester.pumpWidget(TabitalApp(auth: f.auth, customer: f.customer, lock: lock, googleFonts: false));
      await tester.pumpAndSettle();
      return (f, device);
    }

    testWidgets('covers the app and asks the phone straight away', (tester) async {
      final (_, device) = await open(tester);
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      expect(device.prompts, 1);
      expect(find.textContaining("That didn't unlock the app"), findsOneWidget);
      // Nothing from Home can be tapped through the lock
      expect(find.byKey(const Key('pay-bar')).hitTestable(), findsNothing);
    });

    testWidgets('unlocking shows the app', (tester) async {
      final (_, device) = await open(tester, answers: [false, true]);
      await tester.tap(find.byKey(const Key('unlock')));
      await tester.pumpAndSettle();
      expect(device.prompts, 2);
      expect(find.byKey(const Key('lock-screen')), findsNothing);
      expect(find.byKey(const Key('pay-bar')).hitTestable(), findsOneWidget);
    });

    testWidgets('signing in with the password instead signs out and opens Welcome', (tester) async {
      final (f, _) = await open(tester);
      await tester.tap(find.byKey(const Key('lock-sign-in')));
      await tester.pumpAndSettle();
      expect(f.auth.status, AuthStatus.signedOut);
      expect(find.byKey(const Key('lock-screen')), findsNothing);
      expect(find.text('Create account'), findsOneWidget);
    });
  });
}
