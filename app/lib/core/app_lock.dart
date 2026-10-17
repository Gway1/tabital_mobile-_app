import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// The phone's own lock (fingerprint, face, PIN, pattern). Tests use a fake.
abstract class DeviceAuth {
  /// Whether the phone has a screen lock or biometrics the app can ask for.
  Future<bool> available();

  /// Shows the system prompt. True when the person unlocked.
  Future<bool> unlock(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  LocalDeviceAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> unlock(String reason) async {
    try {
      // Biometrics or the phone's PIN/pattern/password, whichever the person uses
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on Exception {
      return false;
    }
  }
}

/// App lock (G9, design brief §7): after [lockAfter] in the background, or when the app opens with
/// a saved session, Tabital asks for the phone's own lock before showing anything. The sign-in
/// token lasts 60 minutes, so this protects a shared or borrowed phone. A phone with no screen lock
/// can't be asked, so the app doesn't lock; the customer can always sign in again instead.
class AppLock extends ChangeNotifier {
  AppLock({required this.device, this.lockAfter = const Duration(minutes: 5), DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DeviceAuth device;
  final Duration lockAfter;
  final DateTime Function() _now;

  bool _locked = false;
  bool _unlocking = false;
  DateTime? _leftAt;

  bool get locked => _locked;
  bool get unlocking => _unlocking;

  /// The app opened with a saved session: lock straight away if the phone can be asked.
  Future<void> lockOnStart() => _lockIfPossible();

  /// The app went to the background.
  void paused() => _leftAt ??= _now();

  /// The app came back. Locks when it was away for [lockAfter] or longer.
  Future<void> resumed() async {
    final left = _leftAt;
    _leftAt = null;
    if (left != null && _now().difference(left) >= lockAfter) await _lockIfPossible();
  }

  Future<void> _lockIfPossible() async {
    if (_locked || !await device.available()) return;
    _locked = true;
    notifyListeners();
  }

  /// Asks the phone. Returns true when unlocked.
  Future<bool> unlock() async {
    if (!_locked) return true;
    if (_unlocking) return false;
    _unlocking = true;
    notifyListeners();
    final ok = await device.unlock('Unlock Tabital Pay to see your plans and payments');
    _unlocking = false;
    if (ok) _locked = false;
    notifyListeners();
    return ok;
  }

  /// Signed out (or chose to sign in again instead): nothing left to protect.
  void clear() {
    _leftAt = null;
    if (!_locked && !_unlocking) return;
    _locked = false;
    _unlocking = false;
    notifyListeners();
  }
}
