/// Build-time settings, passed with `--dart-define`. No secrets live in the app.
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000   (local Flask, from the emulator)
///   flutter build apk --dart-define=API_BASE_URL=https://tabital.onrender.com
abstract final class AppConfig {
  /// The Flask API. Defaults to staging, the same as the web app's staging build.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tabital-api-staging.onrender.com');

  static const supportEmail = 'info@tabitalpay.com';
  static const helpUrl = 'https://tabitalpay.com/help/';
  static const termsUrl = 'https://tabitalpay.com/elementor-page-3332/';
  static const privacyUrl = 'https://tabitalpay.com/privacy-policy/';
}
