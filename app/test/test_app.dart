import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tabital_pay/app.dart';
import 'package:tabital_pay/app_scope.dart';
import 'package:tabital_pay/core/paystack_checkout.dart';
import 'package:tabital_pay/features/auth/auth_controller.dart';
import 'package:tabital_pay/features/identity/document_picker.dart';
import 'package:tabital_pay/features/identity/identity_models.dart';
import 'package:tabital_pay/features/identity/smile_capture.dart';
import 'package:tabital_pay/ui/theme.dart';

import 'fake_api.dart';

/// Paystack's page, faked: records what was opened and "returns" straight away.
class FakeCheckout implements CheckoutLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(BuildContext context, Uri authorizationUrl) async {
    opened.add(authorizationUrl);
    return true;
  }
}

/// Smile ID's camera, faked.
class FakeCamera implements SelfieCamera {
  FakeCamera([this.result]);
  final SelfieCapture? result;
  int opened = 0;

  @override
  Future<SelfieCapture?> capture(BuildContext context) async {
    opened++;
    return result;
  }
}

/// The real router, signed in, starting at [location]. A tall phone screen so whole pages build.
Future<GoRouter> pumpApp(
  WidgetTester tester,
  FakeApi f,
  String location, {
  FakeCheckout? checkout,
  SelfieCamera? camera,
  SmileUploader? smile,
  DocumentPicker? documents,
  Object? extra,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(430 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  f.auth.status = signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
  final router = buildRouter(f.auth);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppScope(
      auth: f.auth,
      customer: f.customer,
      checkout: checkout ?? FakeCheckout(),
      camera: camera ?? FakeCamera(),
      smile: smile,
      documents: documents,
      child: MaterialApp.router(theme: buildTheme(googleFonts: false), routerConfig: router),
    ),
  );
  router.go(location, extra: extra);
  await tester.pumpAndSettle();
  return router;
}

/// The JSON body of the last request to [path].
Map<String, dynamic> lastBody(FakeApi f, String path) {
  // The last request to [path] that sent a body (a screen may reload the same path with a GET after)
  final r = f.requests.lastWhere(
    (r) => r.url.path == path && r.method != 'GET',
    orElse: () => f.requests.lastWhere((r) => r.url.path == path),
  );
  return r.body.isEmpty ? <String, dynamic>{} : (jsonDecode(r.body) as Map).cast<String, dynamic>();
}

/// How many requests went to [method] [path].
int calls(FakeApi f, String method, String path) => f.requests.where((r) => r.method == method && r.url.path == path).length;
