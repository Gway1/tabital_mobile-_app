import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ui/tokens.dart';

/// Opens Paystack's checkout page. Tests use a fake.
abstract class CheckoutLauncher {
  /// Shows the page and returns when Paystack sends the customer back (true) or the
  /// customer closes it (false). Either way the caller asks the server what happened.
  Future<bool> open(BuildContext context, Uri authorizationUrl);
}

/// Paystack in an in-app web view. Paystack returns to `PAYSTACK_CALLBACK_URL` (the web app's
/// `/customer/payment-callback`); the app stops there and verifies with the API instead.
class WebViewCheckoutLauncher implements CheckoutLauncher {
  const WebViewCheckoutLauncher();

  @override
  Future<bool> open(BuildContext context, Uri authorizationUrl) async {
    final done = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaystackCheckoutScreen(url: authorizationUrl)));
    return done ?? false;
  }
}

/// True for the page Paystack returns to after checkout.
bool isPaystackCallback(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.path.endsWith('/payment-callback');
}

/// A checkout page the app will open: https on Paystack's own domains only.
bool isPaystackCheckoutUrl(Uri uri) {
  if (!uri.isScheme('https')) return false;
  final h = uri.host.toLowerCase();
  return h == 'paystack.com' || h.endsWith('.paystack.com') || h == 'paystack.co' || h.endsWith('.paystack.co');
}

enum CheckoutNav { callback, allow, block, external }

/// What the Paystack web view does with a page (M4). Paystack returning to the callback ends
/// checkout. Other https pages load (Paystack, and banks' card checks). Plain http never loads
/// inside a payment page. Bank, USSD and phone links open in their own apps. Script, file and
/// data URLs are blocked.
CheckoutNav checkoutNavigation(String url) {
  if (isPaystackCallback(url)) return CheckoutNav.callback;
  final uri = Uri.tryParse(url);
  if (uri == null) return CheckoutNav.block;
  if (uri.isScheme('https') || url == 'about:blank') return CheckoutNav.allow;
  const blocked = {'http', 'javascript', 'file', 'data', 'content', 'blob', 'about'};
  return blocked.contains(uri.scheme.toLowerCase()) ? CheckoutNav.block : CheckoutNav.external;
}

class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({super.key, required this.url});
  final Uri url;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            switch (checkoutNavigation(req.url)) {
              case CheckoutNav.callback:
                _finish(true);
                return NavigationDecision.prevent;
              case CheckoutNav.allow:
                return NavigationDecision.navigate;
              case CheckoutNav.external:
                // Bank apps, USSD and phone links open outside the web view
                launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication).catchError((_) => false);
                return NavigationDecision.prevent;
              case CheckoutNav.block:
                return NavigationDecision.prevent;
            }
          },
          onPageStarted: (url) {
            if (isPaystackCallback(url)) _finish(true);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  void _finish(bool returned) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(returned);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else {
          _finish(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Close', icon: const Icon(LucideIcons.x), onPressed: () => _finish(false)),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.lock, size: 16),
              SizedBox(width: Tp.s2),
              Text('Secure payment'),
            ],
          ),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
                )
              : null,
        ),
        body: SafeArea(child: WebViewWidget(controller: _web)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tp.s2),
            child: Text(
              'Secured by Paystack. You come back here once the payment is complete.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
