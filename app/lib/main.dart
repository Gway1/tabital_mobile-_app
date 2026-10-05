import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/secure_store.dart';
import 'features/auth/auth_controller.dart';
import 'features/plans/customer_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionStore(SecureStore());
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl, session: session);
  final auth = AuthController(api: api, session: session);
  runApp(TabitalApp(auth: auth, customer: CustomerRepository(api)));
  await auth.restore();
}
