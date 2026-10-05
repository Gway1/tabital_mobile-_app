import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_scope.dart';
import 'core/paystack_checkout.dart';
import 'core/secure_window.dart';
import 'features/account/account_screen.dart';
import 'features/account/limit_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/defer/defer_screen.dart';
import 'features/home/home_screen.dart';
import 'features/identity/identity_screen.dart';
import 'features/identity/smile_capture.dart';
import 'features/pay/pay_screen.dart';
import 'features/pay/payment_result_screen.dart';
import 'features/plans/customer_repository.dart';
import 'features/plans/plan_detail_screen.dart';
import 'features/plans/plans_screen.dart';
import 'features/shop/checkout_screen.dart';
import 'features/shop/orders_screen.dart';
import 'features/shop/product_screen.dart';
import 'features/shop/shop_screen.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

int _id(GoRouterState s, [String name = 'id']) => int.tryParse(s.pathParameters[name] ?? '') ?? 0;

GoRouter buildRouter(AuthController auth) {
  const signedOutPaths = {'/welcome', '/sign-in', '/sign-up'};
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final here = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.unknown:
          return here == '/loading' ? null : '/loading';
        case AuthStatus.signedOut:
          return signedOutPaths.contains(here) ? null : '/welcome';
        case AuthStatus.signedIn:
          return signedOutPaths.contains(here) || here == '/loading' ? '/home' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (_, state) => SignInScreen(initialPhone: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                builder: (_, _) => const ShopScreen(),
                routes: [
                  GoRoute(
                    path: 'product/:id',
                    builder: (_, s) => ProductScreen(productId: _id(s)),
                    routes: [
                      GoRoute(
                        path: 'checkout',
                        // The plan the customer chose travels with the route; without it, choose again
                        builder: (_, s) => s.extra is CheckoutArgs
                            ? CheckoutScreen(args: s.extra as CheckoutArgs)
                            : ProductScreen(productId: _id(s)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/plans', builder: (_, _) => const PlansScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const AccountScreen(),
                routes: [
                  GoRoute(path: 'orders', builder: (_, _) => const OrdersScreen()),
                  GoRoute(path: 'identity', builder: (_, _) => const IdentityScreen()),
              GoRoute(path: 'limit', builder: (_, _) => const LimitScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      // Focused flows open full screen, above the tabs
      GoRoute(
        path: '/plans/:id',
        builder: (_, s) => PlanDetailScreen(planId: _id(s)),
        routes: [
          GoRoute(
            path: 'pay',
            builder: (_, s) =>
                PayScreen(planId: _id(s), initialMode: s.uri.queryParameters['mode'] == 'part' ? PayMode.part : PayMode.instalment),
          ),
          GoRoute(
            path: 'defer',
            builder: (_, s) => DeferScreen(planId: _id(s), paymentId: int.tryParse(s.uri.queryParameters['payment'] ?? '')),
          ),
        ],
      ),
      GoRoute(
        path: '/payment-result/:ref',
        builder: (_, s) => PaymentResultScreen(reference: s.pathParameters['ref'] ?? ''),
      ),
    ],
  );
}

class TabitalApp extends StatefulWidget {
  const TabitalApp({
    super.key,
    required this.auth,
    required this.customer,
    this.checkout = const WebViewCheckoutLauncher(),
    this.camera = const SmileWebCamera(),
    this.googleFonts = true,
  });
  final AuthController auth;
  final CustomerRepository customer;
  final CheckoutLauncher checkout;
  final SelfieCamera camera;
  final bool googleFonts;

  @override
  State<TabitalApp> createState() => _TabitalAppState();
}

class _TabitalAppState extends State<TabitalApp> {
  late final GoRouter _router = buildRouter(widget.auth);
  final _secure = SecureWindow();

  @override
  void initState() {
    super.initState();
    // Hide payment and identity screens from screenshots and the app switcher (M2)
    _router.routerDelegate.addListener(_onRoute);
  }

  void _onRoute() => _secure.forLocation(_router.routerDelegate.currentConfiguration.uri.path);

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRoute);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: widget.auth,
      customer: widget.customer,
      checkout: widget.checkout,
      camera: widget.camera,
      child: MaterialApp.router(
        title: 'Tabital Pay',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(googleFonts: widget.googleFonts),
        themeMode: ThemeMode.light, // the approved design is light only, even when the phone is in dark mode
        routerConfig: _router,
      ),
    );
  }
}

/// Four tabs; Pay is always one tap away from Home.
class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      // `.nav`: white, a thin line on top, navy when chosen
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tp.line))),
        child: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.house), label: 'Home'),
          NavigationDestination(icon: Icon(LucideIcons.shoppingBag), label: 'Shop'),
          NavigationDestination(icon: Icon(LucideIcons.calendarRange), label: 'Plans'),
          NavigationDestination(icon: Icon(LucideIcons.userRound), label: 'Account'),
        ],
      ),
      ),
    );
  }
}
