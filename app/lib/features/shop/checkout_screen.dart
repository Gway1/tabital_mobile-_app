import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../pay/run_checkout.dart';
import 'product_screen.dart';
import 'shop_models.dart';

/// S7: review and pay. Payment 1 (down payment + delivery fee), the full schedule, the total
/// payable and the key facts are all shown before the customer agrees (CLAUDE.md §12).
/// Only the choice is sent; the server prices the order again from the stored product.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.args});
  final CheckoutArgs args;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  bool _agree = false;
  bool _placing = false;
  bool? _paystack;
  String? _error;
  late final TapGestureRecognizer _termsTap;
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => openLink(widget.args.options.keyFacts?.privacyUrl ?? AppConfig.privacyUrl);

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => openLink(widget.args.options.keyFacts?.termsUrl ?? AppConfig.termsUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paystack == null) {
      AppScope.of(context).customer.paystackEnabled().then(
        (v) {
          if (mounted) setState(() => _paystack = v);
        },
        onError: (_) {
          if (mounted) setState(() => _paystack = false);
        },
      );
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    if (_placing) return; // no double orders from a double tap
    if (!(_form.currentState?.validate() ?? false) || !_agree) {
      setState(() => _error = _agree ? null : 'Please agree to the payment schedule and the Terms to continue.');
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });
    final a = widget.args;
    try {
      final res = await AppScope.of(context).customer.purchase(
        productId: a.product.id,
        quantity: a.quantity,
        numberOfPayments: a.option.nPayments,
        deliveryAddress: _address.text,
        acceptTerms: _agree,
      );
      if (!mounted) return;
      final checkout = res.checkout;
      if (checkout != null) {
        final paid = await runCheckout(context, checkout,
            agreed: a.option.dueNow, onCancel: 'Your order is saved. You can pay its down payment from My orders.');
        if (!paid && mounted) context.go('/account/orders');
        return;
      }
      // No payment page: the order went to approval, or Paystack couldn't open (pay from My orders)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message.isNotEmpty ? res.message : 'Order placed. It is waiting for approval.')));
      context.go('/account/orders');
    } on ApiException catch (e) {
      if (!mounted) return;
      final body = e.body;
      final reasons = body is Map ? ((body['reasons'] as List?) ?? const []).map((r) => r.toString()).toList() : const <String>[];
      setState(() => _error = [e.message, ...reasons].join('\n• '));
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to place the order. Please try again.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = widget.args;
    final o = a.option;
    final kf = a.options.keyFacts;
    final paystack = _paystack ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Review and pay')),
      body: Form(
        key: _form,
        child: Column(children: [
          Expanded(
            child: ListView(padding: pagePadding, children: [
              VCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a.product.name}${a.quantity > 1 ? ' × ${a.quantity}' : ''} · ${o.label}', style: t.titleSmall),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('address'),
                    controller: _address,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Delivery to',
                      hintText: 'House number, street, area and a landmark',
                      prefixIcon: Icon(LucideIcons.mapPin, size: 18, color: Tp.muted),
                    ),
                    validator: (v) => (v ?? '').trim().length < 10 ? 'Enter your delivery address (at least 10 characters)' : null,
                  ),
                ]),
              ),
              SectionTitle(o.usesCredit ? 'Pay today (Payment 1)' : 'Pay today'),
              VCard(
                child: Column(children: [
                  if (o.usesCredit)
                    VRow(o.downPaymentPercentage.isEmpty ? 'Down payment' : 'Down payment (${o.downPaymentPercentage}%)',
                        formatPesewas(o.downPayment))
                  else
                    VRow('Product price', formatPesewas(a.options.productPrice)),
                  if (o.deliveryFee > 0) VRow('Delivery fee', formatPesewas(o.deliveryFee)),
                  TotalRow('Due today', formatPesewas(o.dueNow), valueKey: const Key('due-now')),
                ]),
              ),
              if (o.installments > 0) ...[
                const SectionTitle('Then'),
                QuoteSchedule(o, from: 2),
              ] else ...[
                const SizedBox(height: 12),
                VRow('Total payable', formatPesewas(o.totalPayable), valueKey: const Key('schedule-total')),
              ],
              if (kf != null) ...[
                const SectionTitle('Key facts'),
                _KeyFactsList(kf, credit: o.usesCredit),
              ],
              const SizedBox(height: 14),
              CheckRow(
                boxKey: const Key('agree'),
                value: _agree,
                onChanged: (v) => setState(() => _agree = v),
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'I agree to the payment schedule above, the '),
                  TextSpan(text: 'Terms', style: linkStyle, recognizer: _termsTap),
                  const TextSpan(text: ' and the '),
                  TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: _privacyTap),
                  const TextSpan(text: '.'),
                ])),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Notice(_error!, tone: NoticeTone.error),
              ],
              const SizedBox(height: 10),
              Text(
                paystack
                    ? 'Secured by Paystack. Your order goes for approval once the payment is confirmed.'
                    : 'Online payment is off right now. Your order goes for approval, and we will contact you about the down payment.',
                style: t.bodySmall,
              ),
            ]),
          ),
          PayBar(
            button: FilledButton.icon(
              key: const Key('place-order'),
              onPressed: _placing || !_agree ? null : _place,
              icon: _placing ? const ButtonSpinner() : const Icon(LucideIcons.lock, size: 18),
              label: Text(_placing
                  ? 'Placing your order…'
                  : paystack
                      ? 'Pay ${formatPesewas(o.dueNow)}'
                      : 'Place order'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The disclosures (`.facts`), worded like the prototype. Every figure is the server's setting.
class _KeyFactsList extends StatelessWidget {
  const _KeyFactsList(this.kf, {required this.credit});
  final KeyFacts kf;
  final bool credit;

  @override
  Widget build(BuildContext context) {
    final months = '${kf.defermentMonths} month${kf.defermentMonths == 1 ? '' : 's'}';
    final facts = <String>[
      if (credit) '0% interest when you pay on time. Payments are due on the same day each month.',
      if (credit && kf.hasLateFee) ...[
        'A missed payment adds a late fee of ${kf.lateFeePercentage}% of it the day after the due date, '
            'and another ${kf.secondLateFeePercentage}% from ${kf.secondLateFeeAfterDays} days.',
        'Late fees on a plan never go above ${kf.lateFeeCapPercentage}% of the total payable.',
      ],
      if (credit && kf.defermentEnabled && kf.defermentMaxPerPlan > 0)
        'You can move ${kf.defermentMaxPerPlan == 1 ? 'one payment' : 'up to ${kf.defermentMaxPerPlan} payments'} back '
            '$months for a ${kf.defermentFeePercentage}% fee, on or before its due date.',
      'A problem with your order? Report it and your plan is paused while it\'s resolved'
          '${kf.disputeResolutionDays > 0 ? ' (${kf.disputeResolutionDays} days)' : ''}.',
    ];
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5, height: 1.55);
    return Column(children: [
      for (final f in facts)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, right: 10), child: Text('•', style: style)),
            Expanded(child: Text(f, style: style)),
          ]),
        ),
    ]);
  }
}
