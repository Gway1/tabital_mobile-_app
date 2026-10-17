import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../pay/run_checkout.dart';
import 'defer_models.dart';

/// S12: move a payment back for a one-off fee (§4). The fee, the new dates and the new total
/// come from the server and are shown before the customer agrees. The dates only move once
/// Paystack confirms the fee.
class DeferScreen extends StatefulWidget {
  const DeferScreen({super.key, required this.planId, this.paymentId});
  final int planId;
  final int? paymentId;

  @override
  State<DeferScreen> createState() => _DeferScreenState();
}

class _DeferScreenState extends State<DeferScreen> {
  Future<DefermentQuote>? _load;
  bool _agree = false;
  bool _starting = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= _fetch();
  }

  Future<DefermentQuote> _fetch() => AppScope.of(context).customer.defermentQuote(widget.planId, paymentId: widget.paymentId);

  Future<void> _start(DefermentQuote q) async {
    if (_starting || !_agree || q.paymentId == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final start = await AppScope.of(context).customer.startDeferment(widget.planId, q.paymentId!);
      if (!mounted) return;
      await runCheckout(context, start, agreed: q.fee);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, 'Could not start the payment. Please try again.'));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Move a payment back')),
      body: FutureBuilder<DefermentQuote>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorPanel(
              message: errorText(snap.error, "Couldn't check whether this payment can be moved."),
              onRetry: () => setState(() {
                _load = _fetch();
              }),
            );
          }
          return _body(snap.data!);
        },
      ),
    );
  }

  Widget _body(DefermentQuote q) {
    final t = Theme.of(context).textTheme;
    if (!q.allowed) {
      return ListView(
        padding: pagePadding,
        children: [
          Notice(
            q.reasons.isEmpty ? "This payment can't be moved." : q.reasons.join('\n'),
            title: "You can't move this payment",
            tone: NoticeTone.warn,
          ),
        ],
      );
    }
    final months = '${q.months} month${q.months == 1 ? '' : 's'}';
    final canPay = _agree && q.onlinePayment && !_starting;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: pagePadding,
            children: [
              VCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text('One-off fee', style: t.bodySmall),
                    const SizedBox(height: 4),
                    Text(formatPesewas(q.fee), key: const Key('defer-fee'), style: moneyStyle(context, 30)),
                    const SizedBox(height: 4),
                    Text(
                      '${q.feePercentage}% of the ${formatPesewas(q.feeBase)} left on payment ${q.installmentNumber}',
                      key: const Key('defer-fee-basis'),
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SectionTitle('New dates'),
              VCard(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  children: [
                    Lined([
                      for (final m in q.moved)
                        SchedRow(
                          number: m.number,
                          title: 'Payment ${m.number}',
                          subWidget: Text.rich(
                            TextSpan(
                              style: t.bodySmall?.copyWith(fontSize: 12),
                              children: [
                                TextSpan(
                                  text: formatDate(m.dueDate),
                                  style: const TextStyle(decoration: TextDecoration.lineThrough),
                                ),
                                TextSpan(text: ' → ${formatDate(m.newDueDate)}'),
                              ],
                            ),
                            key: Key('defer-move-${m.number}'),
                          ),
                          amount: formatPesewas(m.amount),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Total payable', style: t.bodyMedium?.copyWith(fontSize: 13))),
                        Text.rich(
                          TextSpan(
                            style: t.bodyMedium?.copyWith(fontSize: 13),
                            children: [
                              TextSpan(text: '${formatPesewas(q.totalBefore)} → '),
                              TextSpan(
                                text: formatPesewas(q.totalAfter),
                                style: const TextStyle(color: Tp.navy, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          key: const Key('defer-totals'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Note(
                "It isn't a late payment and doesn't lower your limit, but this plan won't count towards a limit increase. "
                'Payment ${q.installmentNumber} and the ones after it move $months later. '
                'You can move a payment ${q.defermentsLeft} time${q.defermentsLeft == 1 ? '' : 's'} on this plan.',
              ),
              const SizedBox(height: 14),
              CheckRow(
                boxKey: const Key('defer-agree'),
                value: _agree,
                onChanged: (v) => setState(() => _agree = v),
                child: Text('I agree to pay the ${formatPesewas(q.fee)} fee now and to the new dates above.'),
              ),
              if (!q.onlinePayment) ...[
                const SizedBox(height: 12),
                const Notice("Online payment isn't available right now, so the fee can't be paid yet.", tone: NoticeTone.warn),
              ],
              if (_error != null) ...[const SizedBox(height: 12), Notice(_error!, tone: NoticeTone.error)],
            ],
          ),
        ),
        PayBar(
          button: FilledButton.icon(
            key: const Key('defer-button'),
            onPressed: canPay ? () => _start(q) : null,
            icon: _starting ? const ButtonSpinner() : const Icon(LucideIcons.lock, size: 18),
            label: Text(_starting ? 'Opening secure checkout…' : 'Pay ${formatPesewas(q.fee)} and move it'),
          ),
        ),
      ],
    );
  }
}
