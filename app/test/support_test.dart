import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/features/home/home_screen.dart';
import 'package:tabital_pay/app_scope.dart';
import 'package:tabital_pay/features/support/support_models.dart';
import 'package:tabital_pay/ui/theme.dart';

import 'fake_api.dart';
import 'test_app.dart';

// Batch B: report a problem (G5), forgot password (G6), notifications and the bell (G7), plus the
// standing reviewer's plan-detail rules (X1).
void main() {
  Map<String, dynamic> dispute({int planId = 7, String status = 'open'}) => {
    'id': 3,
    'dispute_id': 'DSP-0003',
    'reason': 'defective',
    'description': 'Screen cracked on arrival',
    'amount': 2400.0,
    'status': status,
    'resolution': null,
    'plan_id': planId,
    'product_name': 'Samsung Galaxy A55',
    'paused': status == 'open',
    'respond_by': '2026-10-27',
    'created_at': '2026-10-06T09:00:00',
  };

  group('G5: report a problem', () {
    FakeApi api({List<Map<String, dynamic>> disputes = const [], (int, Object?)? post, Map<String, dynamic>? plan}) => FakeApi({
      'GET /customer/instalments/7': (200, plan ?? referencePlan(secondStatus: 'pending', lateFee: 0)),
      'GET /customer/disputes': (200, {'disputes': disputes}),
      'POST /customer/disputes':
          post ?? (201, {'message': "We've paused your remaining payments while we look into this.", 'dispute': dispute()}),
    });

    testWidgets('an active plan offers it; the report sends the plan, the reason and the description', (tester) async {
      final f = api();
      await pumpApp(tester, f, '/plans/7');
      expect(find.byKey(const Key('plan-report')), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-report')));
      await tester.pumpAndSettle();

      expect(find.text('Report a problem'), findsWidgets);
      await tester.tap(find.byKey(const Key('reason-defective')));
      await tester.enterText(find.byKey(const Key('problem-description')), '  Screen cracked on arrival  ');
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();

      expect(lastBody(f, '/customer/disputes'), {
        'plan_id': 7,
        'reason': 'defective',
        'description': 'Screen cracked on arrival',
      });
      expect(find.text("We've paused your remaining payments while we look into this."), findsOneWidget);
    });

    testWidgets('a description under 10 characters is refused before anything is sent', (tester) async {
      final f = api();
      await pumpApp(tester, f, '/plans/7/report');
      await tester.enterText(find.byKey(const Key('problem-description')), 'broken');
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 10 characters'), findsWidgets);
      expect(calls(f, 'POST', '/customer/disputes'), 0);
    });

    testWidgets("the server's refusal is shown", (tester) async {
      await pumpApp(tester, api(post: (409, {'error': "There's already an open dispute for this purchase"})), '/plans/7/report');
      await tester.enterText(find.byKey(const Key('problem-description')), 'Screen cracked on arrival');
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();
      expect(find.text("There's already an open dispute for this purchase"), findsOneWidget);
    });

    testWidgets('while a report is open the plan says it is paused, and offers no new report or deferment', (tester) async {
      await pumpApp(tester, api(disputes: [dispute()]), '/plans/7');
      expect(find.byKey(const Key('plan-paused')), findsOneWidget);
      expect(find.textContaining('faulty or damaged'), findsOneWidget);
      expect(find.textContaining('27 Oct 2026'), findsOneWidget);
      expect(find.byKey(const Key('plan-report')), findsNothing);
      expect(find.byKey(const Key('plan-defer')), findsNothing);
    });

    testWidgets('a resolved report on another plan changes nothing', (tester) async {
      await pumpApp(
        tester,
        api(
          disputes: [
            dispute(planId: 9),
            dispute(status: 'resolved'),
          ],
        ),
        '/plans/7',
      );
      expect(find.byKey(const Key('plan-paused')), findsNothing);
      expect(find.byKey(const Key('plan-report')), findsOneWidget);
    });
  });

  group('X1: plan detail (web customer-instalments.money.spec.ts)', () {
    FakeApi api(Map<String, dynamic> plan) => FakeApi({
      'GET /customer/instalments/7': (200, plan),
      'GET /customer/disputes': (200, {'disputes': []}),
    });

    testWidgets('paid rows show the payment, unpaid rows what is owed now, and the late fee line', (tester) async {
      await pumpApp(tester, api(referencePlan()), '/plans/7');
      expect(find.text('GHS 1,600.00'), findsWidgets); // Payment 1, paid
      expect(find.text('GHS 880.00'), findsWidgets); // Payment 2: 800 + 80 late fee, from amount_due
      expect(find.text('Includes GHS 80.00 late fee'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('deferment is offered only on an upcoming payment with no late fee', (tester) async {
      await pumpApp(tester, api(referencePlan(secondStatus: 'pending', lateFee: 0)), '/plans/7');
      expect(find.byKey(const Key('plan-defer')), findsOneWidget);
    });

    testWidgets('never on an overdue payment, or one with a late fee', (tester) async {
      await pumpApp(tester, api(referencePlan()), '/plans/7');
      expect(find.byKey(const Key('plan-defer')), findsNothing);
      await pumpApp(tester, api(referencePlan(secondStatus: 'pending', lateFee: 80)), '/plans/7');
      expect(find.byKey(const Key('plan-defer')), findsNothing);
    });

    testWidgets('never on Payment 1', (tester) async {
      final plan = referencePlan(secondStatus: 'pending', lateFee: 0);
      (plan['payment_schedule'] as List).first['status'] = 'pending';
      await pumpApp(tester, api(plan), '/plans/7');
      expect(find.byKey(const Key('plan-defer')), findsNothing);
    });
  });

  group('G6: forgot password', () {
    FakeApi api({(int, Object?)? verify}) => FakeApi({
      'POST /forgot-password': (200, {'message': 'If your account exists, you will receive a password reset email'}),
      'POST /api/verify-otp': verify ?? (200, {'message': 'OTP verified successfully', 'reset_token': 'rt-1'}),
      'POST /reset-password': (200, {'message': 'Password reset successfully. You can now login.'}),
    });

    testWidgets('email, then the code, then a new password, then back to sign in', (tester) async {
      final f = api();
      final router = await pumpApp(tester, f, '/sign-in', signedIn: false);
      await tester.tap(find.byKey(const Key('forgot-password')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('fp-email')), ' Ama@Example.com ');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pump();
      await tester.pump();
      expect(lastBody(f, '/forgot-password'), {'email': 'ama@example.com'});
      expect(find.textContaining('6-digit code sent to Ama@Example.com'), findsOneWidget);
      expect(find.byKey(const Key('fp-wait')), findsOneWidget); // a new code only after a wait

      await tester.enterText(find.byKey(const Key('fp-code')), '123456');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pump();
      await tester.pump();
      expect(lastBody(f, '/api/verify-otp'), {'email': 'ama@example.com', 'otp': '123456'});

      await tester.enterText(find.byKey(const Key('fp-password')), 'a-new-long-pass');
      await tester.enterText(find.byKey(const Key('fp-confirm')), 'a-new-long-pass');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pumpAndSettle(const Duration(seconds: 61));
      expect(lastBody(f, '/reset-password'), {'reset_token': 'rt-1', 'new_password': 'a-new-long-pass'});
      expect(router.state.matchedLocation, '/sign-in');
      expect(find.textContaining('Your password is changed'), findsOneWidget);
    });

    testWidgets("a wrong code shows the server's message and stays on the code step", (tester) async {
      final f = api(verify: (401, {'error': 'That code is wrong or has expired. Request a new code and try again.'}));
      await pumpApp(tester, f, '/forgot-password', signedIn: false);
      await tester.enterText(find.byKey(const Key('fp-email')), 'ama@example.com');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byKey(const Key('fp-code')), '000000');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pumpAndSettle(const Duration(seconds: 61));
      expect(find.text('That code is wrong or has expired. Request a new code and try again.'), findsOneWidget);
      expect(find.byKey(const Key('fp-code')), findsOneWidget);
      expect(calls(f, 'POST', '/reset-password'), 0);
    });

    testWidgets('a short or mismatched password is refused before sending', (tester) async {
      final f = api();
      await pumpApp(tester, f, '/forgot-password', signedIn: false);
      await tester.enterText(find.byKey(const Key('fp-email')), 'ama@example.com');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byKey(const Key('fp-code')), '123456');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byKey(const Key('fp-password')), 'short');
      await tester.enterText(find.byKey(const Key('fp-confirm')), 'other');
      await tester.tap(find.byKey(const Key('fp-submit')));
      await tester.pumpAndSettle(const Duration(seconds: 61));
      expect(find.text('Password must be at least 10 characters'), findsOneWidget);
      expect(find.text("The passwords don't match"), findsOneWidget);
      expect(calls(f, 'POST', '/reset-password'), 0);
    });
  });

  group('G7: notifications and the bell', () {
    Map<String, dynamic> note(int id, {bool read = false, String link = '/customer/instalments'}) => {
      'id': id,
      'notification_id': 'N$id',
      'title': 'Payment due soon',
      'message': 'Payment 2 of GHS 800.00 is due on 3 Nov.',
      'type': 'reminder',
      'read': read,
      'link': link,
      'action_text': 'Pay now',
      'created_at': '2026-10-31T09:00:00',
    };

    FakeApi api(List<Map<String, dynamic>> items, {int unread = 1}) => FakeApi({
      'GET /notifications': (200, {'notifications': items, 'total': items.length}),
      'GET /notifications/unread-count': (200, {'unread_count': unread}),
      'PUT /notifications/5/read': (200, {'message': 'Notification marked as read'}),
      'POST /notifications/mark-all-read': (200, {'message': 'All notifications marked as read'}),
      'GET /customer/instalments': (200, {'plans': []}),
      'GET /customer/dashboard/stats': (200, stats()),
    });

    testWidgets('the bell shows a dot only when there are unread messages', (tester) async {
      Future<void> home(FakeApi f) => tester.pumpWidget(
        AppScope(
          auth: f.auth,
          customer: f.customer,
          child: MaterialApp(
            theme: buildTheme(googleFonts: false),
            home: HomeScreen(today: DateTime(2026, 10, 3)),
          ),
        ),
      );
      await home(api([], unread: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bell')), findsOneWidget);
      expect(find.byKey(const Key('bell-dot')), findsOneWidget);
      expect(find.byTooltip('Notifications, 2 unread'), findsOneWidget);

      await home(api([], unread: 0));
      await tester.pumpAndSettle();
    });

    testWidgets('lists messages; opening one marks it read and goes to the screen it is about', (tester) async {
      final f = api([note(5), note(4, read: true)]);
      final router = await pumpApp(tester, f, '/notifications');
      expect(find.text('Payment due soon'), findsNWidgets(2));
      expect(find.byKey(const Key('unread-5')), findsOneWidget);
      expect(find.byKey(const Key('unread-4')), findsNothing);
      await tester.tap(find.byKey(const Key('notification-5')));
      await tester.pumpAndSettle();
      expect(calls(f, 'PUT', '/notifications/5/read'), 1);
      expect(router.state.matchedLocation, '/plans');
    });

    testWidgets('mark all as read', (tester) async {
      final f = api([note(5), note(6)]);
      await pumpApp(tester, f, '/notifications');
      await tester.tap(find.byKey(const Key('mark-all-read')));
      await tester.pumpAndSettle();
      expect(calls(f, 'POST', '/notifications/mark-all-read'), 1);
      expect(find.byKey(const Key('unread-5')), findsNothing);
      expect(find.byKey(const Key('mark-all-read')), findsNothing);
    });

    testWidgets('an empty inbox says so', (tester) async {
      await pumpApp(tester, api([], unread: 0), '/notifications');
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    test("web links in messages open the app's own screens", () {
      expect(appRouteForLink('/customer/instalments'), '/plans');
      expect(appRouteForLink('/customer/instalments/7'), '/plans/7');
      expect(appRouteForLink('/customer/make-payment?planId=7'), '/plans/7/pay');
      expect(appRouteForLink('/customer/verify-identity'), '/account/identity');
      expect(appRouteForLink('/customer/shop'), '/shop');
      expect(appRouteForLink('/customer/orders'), '/account/orders');
      expect(appRouteForLink('https://evil.test/x'), isNull);
      expect(appRouteForLink(null), isNull);
    });
  });
}
