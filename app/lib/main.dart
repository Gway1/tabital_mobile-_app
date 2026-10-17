import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/app_lock.dart';
import 'core/config.dart';
import 'core/device_flags.dart';
import 'core/secure_store.dart';
import 'features/auth/auth_controller.dart';
import 'features/plans/customer_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionStore(SecureStore());
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl, session: session)
    ..deviceFlags = await readDeviceFlags(); // 'emulator' on an emulator, for the fraud checks
  final auth = AuthController(api: api, session: session);
  final lock = AppLock(device: LocalDeviceAuth());
  // A saved session opens behind the app lock, so a borrowed phone shows nothing (G9)
  await auth.restore();
  if (auth.status == AuthStatus.signedIn) await lock.lockOnStart();
  runApp(TabitalApp(auth: auth, customer: CustomerRepository(api), lock: lock));
}
