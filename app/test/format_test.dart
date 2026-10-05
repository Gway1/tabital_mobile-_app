import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/core/format.dart';

void main() {
  group('money', () {
    test('shows GHS, two decimals and thousands separators', () {
      expect(formatMoney(1650), 'GHS 1,650.00');
      expect(formatMoney(4000.0), 'GHS 4,000.00');
      expect(formatMoney('880.5'), 'GHS 880.50');
      expect(formatMoney(0), 'GHS 0.00');
      expect(formatPesewas(240000), 'GHS 2,400.00');
    });

    test('never shows float noise', () {
      expect(toPesewas(0.1 + 0.2), 30);
      expect(toPesewas(1234.565), 123457);
      expect(formatMoney(0.1 + 0.2), 'GHS 0.30');
    });

    test('a missing amount shows a dash, not zero', () {
      expect(formatMoney(null), '—');
      expect(formatMoney('n/a'), '—');
    });
  });

  group('dates', () {
    test('reads the calendar date and ignores the time', () {
      expect(parseApiDate('2026-11-03T23:30:00'), DateTime(2026, 11, 3));
      expect(parseApiDate('2026-11-03'), DateTime(2026, 11, 3));
      expect(parseApiDate(''), isNull);
      expect(formatDate('2026-11-03T00:00:00'), '3 Nov 2026');
    });

    test('days left uses the same words as the web app', () {
      final today = DateTime(2026, 10, 3);
      expect(daysText(daysUntil(DateTime(2026, 10, 3), today)), 'today');
      expect(daysText(daysUntil(DateTime(2026, 10, 4), today)), 'tomorrow');
      expect(daysText(daysUntil(DateTime(2026, 11, 3), today)), 'in 31 days');
      expect(daysText(daysUntil(DateTime(2026, 10, 2), today)), '1 day ago');
      expect(daysText(daysUntil(DateTime(2026, 10, 1), today)), '2 days ago');
    });
  });

  group('amounts the customer types', () {
    test('read as whole pesewas, never through a float', () {
      expect(parseAmountInput('300'), 30000);
      expect(parseAmountInput('300.5'), 30050);
      expect(parseAmountInput(' 1,200.05 '), 120005);
      expect(parseAmountInput('0.1'), 10);
    });
    test('anything that is not a plain amount is refused', () {
      for (final bad in ['', 'abc', '-5', '1.234', '1e3', '12.', '.5']) {
        expect(parseAmountInput(bad), isNull, reason: bad);
      }
    });
    test('sent to the API as an exact decimal string', () {
      expect(pesewasToApi(30050), '300.50');
      expect(pesewasToApi(5), '0.05');
      expect(pesewasToApi(400000), '4000.00');
      expect(apiDate(DateTime(1990, 1, 5)), '1990-01-05');
    });
  });
}
