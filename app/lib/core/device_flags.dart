import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `X-Device-Flags` for the fraud checks (§9D): `emulator` when the app runs on an Android
/// emulator, otherwise empty. Asked once at start-up from MainActivity.
Future<String> readDeviceFlags({MethodChannel channel = const MethodChannel('com.tabitalpay/device')}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return '';
  try {
    return await channel.invokeMethod<String>('flags') ?? '';
  } on PlatformException {
    return '';
  } on MissingPluginException {
    return '';
  }
}
