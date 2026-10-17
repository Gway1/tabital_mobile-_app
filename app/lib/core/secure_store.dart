import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token and device id are kept. On Android this is the Keystore
/// (flutter_secure_storage). Tests use [MemoryStore].
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureStore implements KeyValueStore {
  SecureStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Session token and the install's device id (fraud checks, §9D).
class SessionStore {
  SessionStore(this._store);
  final KeyValueStore _store;

  static const _tokenKey = 'tabital_access_token';
  static const _deviceKey = 'tabital_device_id';

  String? _token; // kept in memory too, so each request doesn't touch the Keystore
  String? _deviceId;

  String? get token => _token;

  Future<void> load() async => _token = await _store.read(_tokenKey);

  Future<void> saveToken(String token) async {
    _token = token;
    await _store.write(_tokenKey, token);
  }

  /// Signing out clears the token but keeps the device id, the same as the web app.
  Future<void> clearToken() async {
    _token = null;
    await _store.delete(_tokenKey);
  }

  // ---- Offline copy of Home and Plans (G13) ----
  // Kept in the same Keystore-backed store as the token, never on shared storage. Only the plans
  // list and the Home summary are cached: nothing from identity, cards or payments in progress.

  static const _cacheKey = 'tabital_plans_cache';

  Future<String?> readCache() => _store.read(_cacheKey);
  Future<void> writeCache(String json) => _store.write(_cacheKey, json);

  /// On every sign-in and sign-out, so one person never sees another's plans offline.
  Future<void> clearCache() => _store.delete(_cacheKey);

  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    var id = await _store.read(_deviceKey);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await _store.write(_deviceKey, id);
    }
    return _deviceId = id;
  }
}
