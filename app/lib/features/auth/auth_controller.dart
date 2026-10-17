import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/secure_store.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Sign-in state. The token is short-lived (60 minutes on the server) and there's no refresh
/// endpoint yet, so when it expires the customer signs in again.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.session}) {
    api.onUnauthorized = _expired;
  }

  final ApiClient api;
  final SessionStore session;

  AuthStatus status = AuthStatus.unknown;

  /// Shown once on the sign-in screen after the session ended on its own.
  String? notice;

  Future<void> restore() async {
    await session.load();
    status = session.token == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  /// Throws [ApiException] with a message to show.
  Future<void> signIn(String phone, String password) async {
    // The server matches the number as stored ("0241234567"), so drop the spaces the hint shows.
    // It also accepts an email in this field; leave those as typed.
    final id = phone.contains('@') ? phone.trim() : phone.replaceAll(RegExp(r'[\s-]'), '');
    final res = await api.post('/login', {'phone': id, 'password': password});
    if (res is Map && res['two_factor_required'] == true) {
      // Only admin accounts use two-factor sign-in, and admins use the web app
      throw ApiException('This account signs in on the Tabital website, not in the app.');
    }
    final token = res is Map ? res['access_token'] : null;
    if (token is! String || token.isEmpty) throw ApiException("Sign-in didn't work. Please try again.");
    await session.saveToken(token);
    await session.clearCache(); // a new session never sees an earlier one's offline copy

    // The app is for customers. Merchant and admin accounts get a 403 from customer endpoints.
    try {
      await api.get('/customer/dashboard/stats');
    } on ApiException catch (e) {
      if (e.status == 403) {
        await session.clearToken();
        throw ApiException('This app is for shoppers. Merchants and Tabital staff use the website.');
      }
      // Any other problem loading the home screen is shown there, not as a failed sign-in
    }
    notice = null;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  /// Creates a customer account (`POST /register`). Throws [ApiException]; a field the server
  /// rejected is in `body['field']`. The customer signs in afterwards.
  Future<void> register(Map<String, Object?> fields) async {
    await api.post('/register', {...fields, 'role': 'customer'});
    notice = 'Your account is ready. Sign in with your phone number and password.';
    notifyListeners();
  }

  // ---- Forgot password (the web app's three steps; the code goes to the account's email) ----

  /// Asks for a reset code. The server answers the same whether or not the email is registered.
  Future<void> requestResetCode(String email) => api.post('/forgot-password', {'email': email.trim().toLowerCase()});

  /// Checks the 6-digit code and returns the one-time reset token.
  Future<String> verifyResetCode(String email, String code) async {
    final res = await api.post('/api/verify-otp', {'email': email.trim().toLowerCase(), 'otp': code.trim()});
    final token = res is Map ? res['reset_token'] : null;
    if (token is! String || token.isEmpty) {
      throw ApiException('That code is wrong or has expired. Request a new code and try again.');
    }
    return token;
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    await api.post('/reset-password', {'reset_token': resetToken, 'new_password': newPassword});
    notice = 'Your password is changed. Sign in with your new password.';
    notifyListeners();
  }

  Future<void> signOut() async {
    await session.clearToken();
    await session.clearCache();
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  void _expired(String? code) {
    if (status != AuthStatus.signedIn) return;
    // The web app's wording (auth.ts): a suspended account is told so, not that it timed out
    notice = code == 'account_inactive'
        ? "Your account isn't active any more. Please contact Tabital."
        : 'You were signed out to keep your account safe. Please sign in again.';
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
