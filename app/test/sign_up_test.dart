import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tabital_pay/app.dart';
import 'package:tabital_pay/app_scope.dart';
import 'package:tabital_pay/features/auth/auth_controller.dart';
import 'package:tabital_pay/features/auth/sign_up_screen.dart';
import 'package:tabital_pay/ui/theme.dart';

import 'fake_api.dart';
import 'test_app.dart';

void main() {
  group('field checks (the web sign-up rules)', () {
    test('Ghana mobile numbers', () {
      expect(phoneError('0241234567'), isNull);
      expect(phoneError(' 055 123 4567 '), isNull);
      expect(phoneError('0311234567'), isNotNull); // not a mobile prefix
      expect(phoneError('024123456'), isNotNull); // too short
      expect(phoneError('0000000000'), isNotNull);
      expect(phoneError(''), 'Mobile number is required');
    });
    test('passwords of 10 or more characters', () {
      expect(passwordError('short'), contains('at least 10'));
      expect(passwordError('long-enough-1'), isNull);
    });
  });

  Future<(FakeApi, GoRouter)> open(WidgetTester tester, {(int, Object?)? register}) async {
    tester.view.physicalSize = const Size(430 * 3, 3200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final f = FakeApi({
      'POST /register': register ?? (201, {'message': 'User registered successfully'}),
    });
    f.auth.status = AuthStatus.signedOut;
    final router = buildRouter(f.auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      AppScope(
        auth: f.auth,
        customer: f.customer,
        child: MaterialApp.router(theme: buildTheme(googleFonts: false), routerConfig: router),
      ),
    );
    router.go('/sign-up');
    await tester.pumpAndSettle();
    return (f, router);
  }

  final agreeBox = find.descendant(of: find.byKey(const Key('su-agree')), matching: find.byType(Checkbox));

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key('su-$key'));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  Future<void> pickDate(WidgetTester tester, String key, String mmddyyyy) async {
    final field = find.byKey(Key('su-$key'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), mmddyyyy);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> fillAll(WidgetTester tester) async {
    await type(tester, 'full_name', 'Ama Mensah');
    await pickDate(tester, 'dob', '01/15/1990');
    await type(tester, 'business_email', 'ama@example.com');
    await type(tester, 'phone', '0241234567');
    await type(tester, 'national_id', 'GHA-123456789-0');
    await type(tester, 'city', 'Accra');
    await type(tester, 'address', 'House 5, Oxford Street, Osu');
    await type(tester, 'monthly_salary', '5000');
    await pickDate(tester, 'employment_start_date', '03/01/2023');
    await tester.ensureVisible(find.byKey(const Key('su-salary_paid_to_bank')));
    await tester.tap(find.byKey(const Key('su-salary_paid_to_bank')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes').last);
    await tester.pumpAndSettle();
    await type(tester, 'momo_number', '0551234567');
    await type(tester, 'ref_name', 'Kofi Mensah');
    await type(tester, 'ref_phone', '0201234567');
    await type(tester, 'ref_relationship', 'Brother');
    await type(tester, 'password', 'a-long-test-pass');
    await type(tester, 'confirm', 'a-long-test-pass');
    await tester.ensureVisible(find.byKey(const Key('su-agree')));
    await tester.tap(agreeBox); // the box itself: the row's text holds the Terms and Privacy links
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('su-submit')));
    await tester.tap(find.byKey(const Key('su-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a customer account with the web fields, then goes to sign in', (tester) async {
    final (f, router) = await open(tester);
    await fillAll(tester);
    await submit(tester);

    final body = lastBody(f, '/register');
    expect(body['role'], 'customer');
    expect(body['dob'], '1990-01-15');
    expect(body['employment_start_date'], '2023-03-01');
    expect(body['monthly_salary'], '5000');
    expect(body['salary_paid_to_bank'], true);
    expect(body['national_id'], 'GHA-123456789-0');
    expect(body['agree'], true);
    expect(body['marketing_consent'], false);
    expect(body.containsKey('confirm'), isFalse);
    expect(router.state.matchedLocation, '/sign-in');
    expect(find.textContaining('Your account is ready'), findsOneWidget);
  });

  testWidgets('nothing is sent while fields are missing', (tester) async {
    final (f, _) = await open(tester);
    await tester.ensureVisible(find.byKey(const Key('su-agree')));
    await tester.tap(agreeBox); // the box itself: the row's text holds the Terms and Privacy links
    await tester.pump();
    await submit(tester);
    expect(find.text('Please check the highlighted fields.'), findsOneWidget);
    expect(calls(f, 'POST', '/register'), 0);
  });

  testWidgets("the server's reason shows on the field it's about", (tester) async {
    final (_, router) = await open(
      tester,
      register: (
        409,
        {'error': 'This phone number is already registered. Please use a different number or login.', 'field': 'phone'},
      ),
    );
    await fillAll(tester);
    await submit(tester);
    expect(router.state.matchedLocation, '/sign-up');
    expect(find.text('This phone number is already registered. Please use a different number or login.'), findsWidgets);
  });
}
