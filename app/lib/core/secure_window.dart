import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Screens that show payment, plan or identity details. Android hides them from screenshots and
/// the app-switcher preview (`FLAG_SECURE`, design brief §7). Matched against the route path.
final secureRoutes = <RegExp>[
  RegExp(r'^/plans/\d+(/.*)?$'), // plan detail, pay, move a payment back
  RegExp(r'^/payment-result/'), // the result after Paystack
  RegExp(r'^/shop/product/\d+/checkout$'), // review and pay
  RegExp(r'^/account(/.*)?$'), // account, limit, orders, identity
];

bool isSecureLocation(String path) => secureRoutes.any((r) => r.hasMatch(path));

/// Turns `FLAG_SECURE` on or off through MainActivity's `com.tabitalpay/secure` channel.
class SecureWindow {
  SecureWindow({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('com.tabitalpay/secure');
  final MethodChannel _channel;
  bool? _on;

  /// Called on every route change; only talks to Android when the state changes.
  Future<void> forLocation(String path) => set(isSecureLocation(path));

  Future<void> set(bool on) async {
    if (_on == on || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _on = on;
    try {
      await _channel.invokeMethod<bool>('set', on);
    } on PlatformException {
      _on = null; // try again on the next route change
    } on MissingPluginException {
      _on = null;
    }
  }
}
