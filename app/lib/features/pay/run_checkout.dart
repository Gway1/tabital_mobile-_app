import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import 'payment_models.dart';

/// Opens Paystack for a payment the server has started, then shows what the server says
/// happened. The app never decides on its own that a payment went through.
///
/// [agreed] is the amount the customer saw on the button. If the server's amount differs (a late
/// fee was added, or a setting changed in between), the customer sees the new amount and agrees
/// again before Paystack opens (CLAUDE.md §12). Returns false when they don't.
Future<bool> runCheckout(
  BuildContext context,
  CheckoutStart start, {
  required int agreed,
  bool replace = true,
  String? onCancel,
}) async {
  final scope = AppScope.of(context);
  final router = GoRouter.of(context);
  if (start.amount != agreed) {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const Key('amount-changed'),
        title: const Text('The amount has changed'),
        content: Text(
          'You agreed to pay ${formatPesewas(agreed)}. Paystack will now charge ${formatPesewas(start.amount)}, '
          'for example because a late fee was added.\n\nDo you want to pay ${formatPesewas(start.amount)}?'
          '${onCancel == null ? '' : '\n\n$onCancel'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Pay ${formatPesewas(start.amount)}')),
        ],
      ),
    );
    if (ok != true) return false;
  }
  if (!context.mounted) return false;
  await scope.checkout.open(context, start.authorizationUrl);
  final result = '/payment-result/${Uri.encodeComponent(start.reference)}';
  if (replace) {
    router.pushReplacement(result);
  } else {
    router.push(result);
  }
  return true;
}
