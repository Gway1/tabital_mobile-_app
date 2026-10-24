import 'package:flutter/widgets.dart';

import 'core/paystack_checkout.dart';
import 'features/auth/auth_controller.dart';
import 'features/identity/document_picker.dart';
import 'features/identity/smile_capture.dart';
import 'features/plans/customer_repository.dart';

/// Gives screens the shared services. Tests build it with fakes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.customer,
    this.checkout = const WebViewCheckoutLauncher(),
    this.camera = const SmileWebCamera(),
    this.smile,
    this.documents,
    required super.child,
  });

  final AuthController auth;
  final CustomerRepository customer;

  /// Paystack's checkout page.
  final CheckoutLauncher checkout;

  /// Smile ID's selfie camera, and the upload to Smile ID.
  final SelfieCamera camera;
  final SmileUploader? smile;

  /// Picks a document photo or file for verification (U5). Null: the device's own pickers.
  final DocumentPicker? documents;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      auth != oldWidget.auth || customer != oldWidget.customer || checkout != oldWidget.checkout || camera != oldWidget.camera;
}
