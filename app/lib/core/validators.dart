import 'format.dart';

/// Field checks shared by sign-up and the verification details (the web forms' rules). The server
/// checks everything again; these only catch typing mistakes early.

/// Ghana mobile numbers, the same check as the web forms.
final _ghanaMobile = RegExp(r'^(054|055|059|020|024|025|026|027|050|053|057|056)[0-9]{7}$');

String? phoneError(String? v, {bool required = true}) {
  final s = (v ?? '').trim().replaceAll(' ', '');
  if (s.isEmpty) return required ? 'Mobile number is required' : null;
  if (!_ghanaMobile.hasMatch(s) || RegExp(r'^(\d)\1{9}$').hasMatch(s)) {
    return 'Please enter a valid Ghana mobile number (e.g., 024XXXXXXX)';
  }
  return null;
}

String? passwordError(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Password is required';
  if (s.length < 10) return 'Password must be at least 10 characters';
  if (s.length > 128) return 'Password is too long (maximum 128 characters)';
  return null;
}

String? emailError(String? v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Please enter a valid email address';

/// The server's rule: GHA, 9 digits, 1 digit, with any spaces or dashes.
String? ghanaCardError(String? v) => RegExp(r'^GHA\d{10}$').hasMatch((v ?? '').toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), ''))
    ? null
    : 'Enter the Ghana Card number as GHA-XXXXXXXXX-X';

/// The card number as the server stores it: GHA-123456789-0.
String normaliseGhanaCard(String v) {
  final s = v.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
  final m = RegExp(r'^GHA(\d{9})(\d)$').firstMatch(s);
  return m == null ? v.trim().toUpperCase() : 'GHA-${m.group(1)}-${m.group(2)}';
}

String? salaryError(String? v) {
  final p = parseAmountInput(v ?? '');
  return p == null || p <= 0 ? 'Enter your monthly salary, e.g. 5000' : null;
}
