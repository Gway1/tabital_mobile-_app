import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'secure_store.dart';

/// An API failure with a message that's safe to show the customer.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.body});
  final String message;
  final int? status;
  final Object? body;

  bool get unauthorized => status == 401;

  /// The request never reached the server (no data, no Wi-Fi, timed out).
  bool get offline => status == null;

  /// The server's machine-readable reason, e.g. `account_inactive`, `terms_not_accepted`.
  String? get code => body is Map ? (body as Map)['code']?.toString() : null;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Talks to the Flask API. Sends the session token and device id to our own API only.
class ApiClient {
  ApiClient({required this.baseUrl, required this.session, http.Client? client, this.timeout = const Duration(seconds: 30)})
    : _http = client ?? http.Client();

  final String baseUrl;
  final SessionStore session;
  final http.Client _http;
  final Duration timeout;

  /// Called when the server says the session has ended (401), so the app can go to sign-in.
  /// [code] is `account_inactive` when the account was suspended.
  void Function(String? code)? onUnauthorized;

  /// Sent as `X-Device-Flags` (e.g. `emulator`), which the server's fraud checks read (§9D).
  String? deviceFlags;

  /// False after a request couldn't reach the server, true again after any answer (G13). Pay,
  /// checkout, defer and report stay off while it's false.
  final online = ValueNotifier<bool>(true);

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final req = http.Request(method, uri);
    req.headers['Accept'] = 'application/json';
    final token = session.token;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['X-Device-Id'] = await session.deviceId();
    final flags = deviceFlags;
    if (flags != null && flags.isNotEmpty) req.headers['X-Device-Flags'] = flags;
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException {
      online.value = false;
      throw ApiException('The connection timed out. Check your data or Wi-Fi and try again.');
    } on Exception {
      online.value = false;
      throw ApiException("Can't reach Tabital right now. Check your data or Wi-Fi and try again.");
    }

    Object? data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } on FormatException {
        data = null;
      }
    }

    online.value = true;
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && token != null) {
      await session.clearToken();
      onUnauthorized?.call(data is Map ? data['code']?.toString() : null);
    }
    throw ApiException(_message(data, res.statusCode), status: res.statusCode, body: data);
  }

  static String _message(Object? data, int status) {
    if (data is Map) {
      for (final k in const ['message', 'error', 'msg']) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
    }
    if (status == 401) return 'Please sign in again.';
    if (status == 429) return 'Too many attempts. Please wait a moment and try again.';
    if (status >= 500) return 'Something went wrong on our side. Please try again shortly.';
    return 'That didn\'t work. Please try again.';
  }
}
