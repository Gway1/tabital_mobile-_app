/// Build-time settings, passed with `--dart-define`. No secrets live in the app.
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000   (local Flask, from the emulator)
///   flutter build apk                                              (the live API)
abstract final class AppConfig {
  /// The Flask API. Defaults to the live API (U1, 2026-10-25); override with --dart-define.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tabital-backend.onrender.com');

  static const supportEmail = 'info@tabitalpay.com';
  static const helpUrl = 'https://tabitalpay.com/help/';
  static const termsUrl = 'https://tabitalpay.com/elementor-page-3332/';
  static const privacyUrl = 'https://tabitalpay.com/privacy-policy/';

  /// The company line for the Account page (handoff §4: the legal entity).
  static const legalLine = 'Tabital Pay Ltd · Registration CS 117960626';
}
