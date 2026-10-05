import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'payment_models.dart';

/// S9: after Paystack. Asks the server to verify the payment and shows what it says. It never
/// shows "paid" unless the server applied the payment.
class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({super.key, required this.reference});
  final String reference;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  Future<PaymentResult>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= _verify();
  }

  Future<PaymentResult> _verify() async {
    final customer = AppScope.of(context).customer;
    final r = await customer.verifyPayment(widget.reference);
    customer.changed(); // plans, orders and the limit may have changed
    return r;
  }

  void _again() => setState(() {
    _load = _verify();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Payment'),
        actions: [IconButton(tooltip: 'Close', icon: const Icon(LucideIcons.x), onPressed: () => context.go('/home'))],
      ),
      body: SafeArea(
        child: FutureBuilder<PaymentResult>(
          future: _load,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _Panel(
                icon: null,
                title: 'Confirming your payment…',
                text: "We're checking with Paystack. This usually takes a few seconds.",
              );
            }
            if (snap.hasError) {
              return _Panel(
                icon: LucideIcons.circleAlert,
                tone: Tp.error,
                title: "Couldn't confirm the payment",
                text: errorText(snap.error, 'We could not confirm the payment yet.'),
                reference: widget.reference,
                actions: [
                  OutlinedButton(onPressed: _again, child: const Text('Check again')),
                  FilledButton(onPressed: () => context.go('/plans'), child: const Text('Back to my plans')),
                ],
              );
            }
            return _result(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _result(PaymentResult r) {
    final ref = widget.reference;
    void plans() => context.go('/plans');
    void orders() => context.go('/account/orders');
    void retry() {
      if (r.isDownPayment) {
        orders();
      } else if (r.planId != null) {
        context.go('/plans');
        context.push('/plans/${r.planId}/pay');
      } else {
        plans();
      }
    }

    switch (r.state) {
      case PaymentState.paid when r.isDownPayment:
        return _Panel(
          icon: LucideIcons.check,
          tone: Tp.success,
          title: 'Down payment received',
          text: '${formatPesewas(r.amount)} received for order ${r.orderId ?? ''}.',
          note: r.note ?? "Your order is waiting for approval. We'll message you as soon as it's approved.",
          reference: ref,
          extra: const VCard(
            child: StepsList([
              (LucideIcons.check, 'Down payment paid', IconTone.ok),
              (LucideIcons.clipboardCheck, 'Tabital approves your order', IconTone.navy),
              (LucideIcons.truck, 'The shop delivers', IconTone.navy),
              (LucideIcons.calendar, 'Then you pay monthly, as in your schedule', IconTone.navy),
            ]),
          ),
          actions: [FilledButton(onPressed: orders, child: const Text('View my order'))],
        );
      case PaymentState.paid:
        return _Panel(
          icon: LucideIcons.check,
          tone: Tp.success,
          title: 'Payment confirmed',
          text: r.isSettlement
              ? '${formatPesewas(r.amount)} to pay off your plan has been received.'
              : '${formatPesewas(r.amount)} for payment ${r.installmentNumber} has been received.',
          note: r.note,
          reference: ref,
          actions: [FilledButton(onPressed: plans, child: const Text('View my plans'))],
        );
      case PaymentState.deferred:
        return _Panel(
          icon: LucideIcons.calendarCheck,
          tone: Tp.success,
          title: 'Payment moved',
          text:
              'We received the ${formatPesewas(r.amount)} deferment fee. Payment ${r.installmentNumber} '
              'and the payments after it now have new due dates.',
          reference: ref,
          actions: [FilledButton(onPressed: plans, child: const Text('See my new dates'))],
        );
      case PaymentState.refund when r.isDeferment:
        return _Panel(
          icon: LucideIcons.undo2,
          tone: Tp.warn,
          title: "The payment couldn't be moved",
          text:
              'Something changed while your payment was going through (for example the payment was already made). '
              "Your payment dates stay the same, and we'll refund the deferment fee.",
          reference: ref,
          actions: [FilledButton(onPressed: plans, child: const Text('View my plans'))],
        );
      case PaymentState.refund:
        return _Panel(
          icon: LucideIcons.undo2,
          tone: Tp.warn,
          title: 'Order already closed',
          text: 'This order was closed before your payment arrived. Your money will be refunded.',
          reference: ref,
          actions: [FilledButton(onPressed: orders, child: const Text('View my orders'))],
        );
      case PaymentState.pending:
        return _Panel(
          icon: LucideIcons.hourglass,
          tone: Tp.warn,
          title: 'Payment not confirmed yet',
          text: 'If you approved the payment, it will update automatically once Paystack confirms it.',
          reference: ref,
          actions: [
            OutlinedButton(onPressed: _again, child: const Text('Check again')),
            FilledButton(
              onPressed: r.isDownPayment ? orders : plans,
              child: Text(r.isDownPayment ? 'View my orders' : 'Back to my plans'),
            ),
          ],
        );
      case PaymentState.failed:
        return _Panel(
          icon: LucideIcons.circleX,
          tone: Tp.error,
          title: "Payment didn't go through",
          text: 'No money was taken for this attempt. You can try again.',
          reference: ref,
          actions: [
            OutlinedButton(onPressed: r.isDownPayment ? orders : plans, child: Text(r.isDownPayment ? 'My orders' : 'My plans')),
            FilledButton(onPressed: retry, child: const Text('Try again')),
          ],
        );
      case PaymentState.mismatch:
        return _Panel(
          icon: LucideIcons.triangleAlert,
          tone: Tp.warn,
          title: 'We need to check this payment',
          text: "The amount received doesn't match what was due, so it hasn't been applied yet. Our team will review it.",
          reference: ref,
          actions: [FilledButton(onPressed: plans, child: const Text('Back to my plans'))],
        );
      case PaymentState.error:
        return _Panel(
          icon: LucideIcons.circleAlert,
          tone: Tp.error,
          title: "Couldn't confirm the payment",
          text: 'We could not confirm the payment yet.',
          reference: ref,
          actions: [OutlinedButton(onPressed: _again, child: const Text('Check again'))],
        );
    }
  }
}

/// The prototype's S9: a big icon, the title and message, any next steps, and the main action in
/// the bottom bar. [actions]: the last one is the main action; any others sit above it.
class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.text, this.tone = Tp.navy2, this.note, this.reference, this.actions = const [], this.extra});
  final IconData? icon;
  final Color tone;
  final String title;
  final String text;
  final String? note;
  final String? reference;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final iconTone = switch (tone) {
      Tp.success => IconTone.ok,
      Tp.error => IconTone.error,
      Tp.warn => IconTone.warn,
      _ => IconTone.navy,
    };
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(Tp.s6, 56, Tp.s6, Tp.s4), children: [
          Center(
            child: icon == null
                ? const SizedBox(width: 84, height: 84, child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator()))
                : BigIcon(icon!, tone: iconTone),
          ),
          const SizedBox(height: 18),
          Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, key: const Key('result-text'), style: t.bodyMedium?.copyWith(height: 1.5)),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, textAlign: TextAlign.center, key: const Key('result-note'), style: t.bodySmall),
          ],
          if (extra != null) ...[const SizedBox(height: 24), extra!],
          if (actions.length > 1) ...[
            const SizedBox(height: 24),
            for (final a in actions.take(actions.length - 1)) Padding(padding: const EdgeInsets.only(bottom: Tp.s2), child: a),
          ],
          if (reference != null) ...[
            const SizedBox(height: Tp.s4),
            Text('Reference: $reference', textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontSize: 12)),
          ],
        ]),
      ),
      if (actions.isNotEmpty) PayBar(button: actions.last),
    ]);
  }
}
