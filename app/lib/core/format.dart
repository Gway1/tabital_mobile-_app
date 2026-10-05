import 'package:intl/intl.dart';

/// Display helpers only. The app never calculates an amount: every figure comes from the API.

final _money = NumberFormat('#,##0.00', 'en_US');
final _date = DateFormat('d MMM yyyy', 'en_US');

/// Reads an API amount (number or numeric string) as whole pesewas, so display never
/// shows float noise. Returns null when the value isn't a number.
int? toPesewas(Object? value) {
  if (value == null) return null;
  if (value is int) return value * 100;
  if (value is num) return (value * 100).round();
  final parsed = num.tryParse(value.toString().trim());
  return parsed == null ? null : (parsed * 100).round();
}

/// Money as `GHS 1,650.00`: the ISO code, two decimals, thousands separators. Never "GHC" or "₵".
String formatMoney(Object? value) {
  final p = toPesewas(value);
  return p == null ? '—' : formatPesewas(p);
}

/// [formatMoney] for an amount already held in pesewas.
String formatPesewas(int p) {
  final sign = p < 0 ? '-' : '';
  return 'GHS $sign${_money.format(p.abs() / 100)}';
}

/// The calendar date in an API value such as `2026-11-03T00:00:00` or `2026-11-03`.
/// Due dates are calendar days, so the time part and time zone are ignored.
DateTime? parseApiDate(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  if (s.length < 10) return null;
  final d = DateTime.tryParse(s.substring(0, 10));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// Dates as `3 Nov 2026`.
String formatDate(Object? value) {
  final d = value is DateTime ? value : parseApiDate(value);
  return d == null ? '—' : _date.format(d);
}

/// Whole days from [today] to [due] (negative when the date has passed).
int daysUntil(DateTime due, DateTime today) {
  final a = DateTime.utc(today.year, today.month, today.day);
  final b = DateTime.utc(due.year, due.month, due.day);
  return b.difference(a).inDays;
}

/// "today", "tomorrow", "in 3 days", "2 days ago", the same words as the web app.
String daysText(int days) {
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days > 1) return 'in $days days';
  return '${-days} day${days == -1 ? '' : 's'} ago';
}

/// What the customer typed in an amount box ("300", "300.5", "1,200.00") as whole pesewas.
/// Null when it isn't a plain amount with at most two decimals. This only reads the input;
/// the server still checks it against what's owed.
int? parseAmountInput(String text) {
  final s = text.trim().replaceAll(',', '');
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final cedis = int.parse(m.group(1)!);
  final pesewas = int.parse((m.group(2) ?? '0').padRight(2, '0'));
  return cedis * 100 + pesewas;
}

/// Pesewas as the decimal string the API reads with `Decimal(str(...))`, e.g. 30050 -> "300.50".
/// Sent as text so the amount never passes through a float.
String pesewasToApi(int p) => '${p ~/ 100}.${(p % 100).toString().padLeft(2, '0')}';

/// A calendar date as the API's `YYYY-MM-DD`.
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
