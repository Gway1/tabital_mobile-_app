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

  Future<void> signOut() async {
    await session.clearToken();
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  void _expired() {
    if (status != AuthStatus.signedIn) return;
    notice = 'You were signed out to keep your account safe. Please sign in again.';
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
