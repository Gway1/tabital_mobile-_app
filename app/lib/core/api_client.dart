import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'secure_store.dart';

/// An API failure with a message that's safe to show the customer.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.body});
  final String message;
  final int? status;
  final Object? body;

  bool get unauthorized => status == 401;

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
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final req = http.Request(method, uri);
    req.headers['Accept'] = 'application/json';
    final token = session.token;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['X-Device-Id'] = await session.deviceId();
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException {
      throw ApiException('The connection timed out. Check your data or Wi-Fi and try again.');
    } on Exception {
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

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && token != null) {
      await session.clearToken();
      onUnauthorized?.call();
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
