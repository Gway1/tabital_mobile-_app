import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/app_scope.dart';
import 'package:tabital_pay/features/home/home_screen.dart';
import 'package:tabital_pay/ui/theme.dart';

import 'fake_api.dart';

Widget _home(FakeApi f, {DateTime? today}) => AppScope(
  auth: f.auth,
  customer: f.customer,
  child: MaterialApp(
    theme: buildTheme(googleFonts: false),
    home: HomeScreen(today: today ?? DateTime(2026, 10, 3)),
  ),
);

void main() {
  testWidgets('overdue: the card shows the server total and the late fee as its own line', (tester) async {
    final f = FakeApi({
      'GET /customer/dashboard/stats': (200, stats()),
      'GET /customer/instalments': (
        200,
        {
          'plans': [referencePlan()],
        },
      ),
    });
    await tester.pumpWidget(_home(f));
    await tester.pumpAndSettle();

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('next-amount'), 'GHS 880.00');
    expect(text('next-late-fee'), 'GHS 80.00'); // the late fee on its own line, under payment 2
    expect(find.text('Payment 2'), findsOneWidget);
    expect(find.text('OVERDUE PAYMENT'), findsOneWidget);
    expect(find.text('Overdue 2 days'), findsOneWidget);
    expect(text('next-due'), 'Was due 1 Oct 2026');
    expect(text('next-progress'), 'GHS 1,600.00 of GHS 4,000.00 paid');
    expect(text('pay-bar-amount'), 'GHS 880.00');
    expect(find.text('Pay now'), findsOneWidget);
    expect(find.text('Pay part of it'), findsOneWidget);
    expect(text('available-limit'), 'GHS 2,600.00 available');
    expect(find.text('of GHS 5,000.00 · grows when you pay on time'), findsOneWidget);
  });

  testWidgets('on time: next payment, days left, no late fee line', (tester) async {
    final f = FakeApi({
      'GET /customer/dashboard/stats': (200, stats()),
      'GET /customer/instalments': (
        200,
        {
          'plans': [referencePlan(secondStatus: 'pending', lateFee: 0)],
        },
      ),
    });
    await tester.pumpWidget(_home(f, today: DateTime(2026, 9, 28)));
    await tester.pumpAndSettle();

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('next-amount'), 'GHS 800.00');
    expect(text('next-due'), 'Due 1 Oct 2026');
    expect(find.text('In 3 days'), findsOneWidget);
    expect(find.byKey(const Key('next-late-fee')), findsNothing);
    expect(find.text('OVERDUE PAYMENT'), findsNothing);
    expect(text('pay-bar-amount'), 'GHS 800.00');
    expect(find.text('Due 1 Oct'), findsOneWidget);
  });

  testWidgets('nothing due: no pay bar, a way to the shop', (tester) async {
    final f = FakeApi({
      'GET /customer/dashboard/stats': (200, stats()),
      'GET /customer/instalments': (200, {'plans': []}),
    });
    await tester.pumpWidget(_home(f));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to pay right now'), findsOneWidget);
    expect(find.byKey(const Key('pay-bar')), findsNothing);
  });

  testWidgets('limit not available shows the server reason', (tester) async {
    final f = FakeApi({
      'GET /customer/dashboard/stats': (200, stats(eligible: false)),
      'GET /customer/instalments': (
        200,
        {
          'plans': [referencePlan()],
        },
      ),
    });
    await tester.pumpWidget(_home(f));
    await tester.pumpAndSettle();

    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.text('A payment is overdue'), findsOneWidget);
  });

  testWidgets('a failed load shows the message and a retry', (tester) async {
    final f = FakeApi({
      'GET /customer/dashboard/stats': (500, {'error': 'Database unavailable'}),
    });
    await tester.pumpWidget(_home(f));
    await tester.pumpAndSettle();

    expect(find.text('Database unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('pay-bar')), findsNothing);
  });
}
