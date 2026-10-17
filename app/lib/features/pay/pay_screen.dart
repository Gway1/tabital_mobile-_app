import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../cards/card_models.dart';
import '../plans/plan_models.dart';
import 'payment_models.dart';
import 'run_checkout.dart';

enum PayMode { instalment, part, settle }

/// S11: pay the next payment, part of it, or everything left on the plan (R5), through Paystack.
/// Every amount comes from the server; the customer only chooses.
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.planId, this.initialMode = PayMode.instalment});
  final int planId;

  /// Home's "Pay part of it" opens straight on part payment.
  final PayMode initialMode;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayData {
  _PayData(this.plan, this.payment, this.paystack);
  final Plan plan;
  final ScheduleItem? payment; // the next payment the server will charge
  final bool paystack;
}

class _PayScreenState extends State<PayScreen> {
  Future<_PayData>? _load;
  late PayMode _mode = widget.initialMode;
  final _part = TextEditingController();
  Future<SettlementQuote>? _quote;
  bool _starting = false;
  List<SavedCard> _cards = const []; // shown under "Pay with"; Paystack still asks how to pay
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_load == null) {
      _load = _fetch();
      AppScope.of(context).customer.savedCards().then((c) {
        if (mounted) setState(() => _cards = c);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _part.dispose();
    super.dispose();
  }

  Future<_PayData> _fetch() async {
    final customer = AppScope.of(context).customer;
    final results = await Future.wait<Object>([customer.plan(widget.planId), customer.paystackEnabled()]);
    final plan = results[0] as Plan;
    final next = plan.schedule
        .where((s) => s.status == 'pending' || s.status == 'overdue' || s.status == 'pending_verification')
        .firstOrNull;
    return _PayData(plan, next, results[1] as bool);
  }

  void _setMode(PayMode m) {
    setState(() {
      _mode = m;
      _error = null;
      // The screen shows a failed quote itself, so its error is never left unhandled
      if (m == PayMode.settle) _quote ??= AppScope.of(context).customer.settlementQuote(widget.planId)..ignore();
    });
  }

  int? get _partPesewas => parseAmountInput(_part.text);

  /// Checks the typed amount against what's due. The server checks again.
  String? _partError(ScheduleItem payment) {
    if (_part.text.trim().isEmpty) return null;
    final p = _partPesewas;
    if (p == null || p <= 0) return 'Enter the amount to pay, e.g. 300 or 300.50';
    if (p > payment.amountDue) {
      return "That's more than the ${formatPesewas(payment.amountDue)} due. To pay more, pay off the whole plan.";
    }
    return null;
  }

  Future<void> _pay(_PayData d, {SettlementQuote? quote}) async {
    if (_starting) return; // one checkout per tap
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final customer = AppScope.of(context).customer;
      final start = switch (_mode) {
        PayMode.instalment => await customer.startPlanPayment(widget.planId),
        PayMode.part => await customer.startPlanPayment(widget.planId, partAmount: _partPesewas),
        PayMode.settle => await customer.startPlanPayment(widget.planId, settle: true),
      };
      if (!mounted) return;
      final agreed = switch (_mode) {
        PayMode.instalment => d.payment!.amountDue,
        PayMode.part => _partPesewas!,
        PayMode.settle => quote!.total,
      };
      await runCheckout(context, start, agreed: agreed);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, 'Could not start the payment. Please try again.'));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make a payment')),
      body: FutureBuilder<_PayData>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorPanel(
              message: errorText(snap.error, "Couldn't load this plan."),
              onRetry: () => setState(() {
                _load = _fetch();
              }),
            );
          }
          final d = snap.data!;
          final payment = d.payment;
          if (payment == null) {
            return const EmptyState(
              icon: LucideIcons.circleCheck,
              title: 'Nothing to pay on this plan',
              text: 'Every payment is made.',
            );
          }
          return _body(d, payment);
        },
      ),
    );
  }

  Widget _body(_PayData d, ScheduleItem payment) {
    final t = Theme.of(context).textTheme;
    final checking = payment.status == 'pending_verification';
    final overdue = payment.status == 'overdue';
    return FutureBuilder<SettlementQuote>(
      future: _mode == PayMode.settle ? _quote : null,
      builder: (context, quoteSnap) {
        final quote = quoteSnap.data;
        final partError = _partError(payment);
        final (int? charge, bool ready) = switch (_mode) {
          PayMode.instalment => (payment.amountDue, payment.amountDue > 0),
          PayMode.part => (_partPesewas, _partPesewas != null && _partPesewas! > 0 && partError == null),
          PayMode.settle => (quote?.total, quote != null && quote.total > 0),
        };
        final canPay = d.paystack && ready && !_starting && !checking;

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: pagePadding,
                children: [
                  Segmented<PayMode>(
                    value: _mode,
                    options: const [
                      (PayMode.instalment, 'This payment'),
                      (PayMode.part, 'Pay part'),
                      (PayMode.settle, 'Pay off plan'),
                    ],
                    onChanged: _setMode,
                  ),
                  const SizedBox(height: Tp.s4),
                  if (_mode == PayMode.instalment || _mode == PayMode.part)
                    VCard(
                      child: Column(
                        children: [
                          VRow(
                            'Payment ${payment.number} · ${overdue ? 'was due' : 'due'} ${formatDate(payment.dueDate)}',
                            formatPesewas(payment.amountDue),
                            valueKey: const Key('pay-due'),
                          ),
                          if (payment.lateFee > 0) ...[
                            const SizedBox(height: 4),
                            VRow(
                              'Includes the late fee',
                              formatPesewas(payment.lateFee),
                              size: 13,
                              valueColor: Tp.error,
                              valueKey: const Key('pay-late-fee'),
                            ),
                          ],
                          if (payment.partPaid > 0) VRow('Already paid towards it', formatPesewas(payment.partPaid), size: 13),
                        ],
                      ),
                    ),
                  if (_mode == PayMode.part) ...[
                    const SizedBox(height: Tp.s4),
                    Text('Amount to pay now', style: t.bodySmall),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('part-amount'),
                      controller: _part,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: moneyStyle(context, 20),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 8),
                          child: Text(
                            'GHS',
                            style: t.bodyMedium?.copyWith(color: Tp.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0.00',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Tp.navy, width: 1.5),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Tp.s2),
                    Text(
                      partError ??
                          "The rest of this payment stays due. Late fees apply to what's still unpaid after the due date.",
                      style: t.bodySmall?.copyWith(color: partError == null ? Tp.muted : Tp.error),
                    ),
                  ],
                  if (_mode == PayMode.settle) ...[
                    if (quoteSnap.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(Tp.s4),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (quoteSnap.hasError)
                      Notice(errorText(quoteSnap.error, "Couldn't work out what's left to pay."), tone: NoticeTone.error)
                    else if (quote != null) ...[
                      VCard(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        child: Column(
                          children: [
                            Lined([
                              for (final l in quote.lines)
                                SchedRow(
                                  number: l.number,
                                  title: 'Payment ${l.number}',
                                  sub: [
                                    if (l.lateFee > 0) 'includes ${formatPesewas(l.lateFee)} late fee',
                                    if (l.alreadyPaid > 0) 'after ${formatPesewas(l.alreadyPaid)} paid',
                                  ].join(' · ').ifEmptyNull,
                                  amount: formatPesewas(l.owed),
                                ),
                            ]),
                            TotalRow('To pay off the plan', formatPesewas(quote.total), valueKey: const Key('settle-total')),
                          ],
                        ),
                      ),
                      if (quote.note.isNotEmpty) ...[const SizedBox(height: 12), Note(quote.note, icon: LucideIcons.badgeCheck)],
                    ],
                  ],
                  const SectionTitle('Pay with'),
                  VCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    child: Lined([
                      const ListRow(icon: LucideIcons.smartphone, label: 'Mobile Money', trailing: Text('MTN · Telecel · AT')),
                      if (_cards.isEmpty)
                        const ListRow(icon: LucideIcons.creditCard, label: 'Card', trailing: Text('Visa · Mastercard'))
                      else
                        for (final c in _cards)
                          ListRow(
                            key: Key('pay-card-${c.id}'),
                            icon: LucideIcons.creditCard,
                            label: '${c.name} •••• ${c.last4}',
                            trailing: VChip(c.autopay ? 'Autopay on' : 'Autopay off'),
                            onTap: () => context.push('/account/cards'),
                          ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(LucideIcons.shield, size: 15, color: Tp.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Secured by Paystack. You choose on Paystack's page; your payment shows once Paystack confirms it.",
                          style: t.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (checking) ...[
                    const SizedBox(height: 12),
                    const Notice(
                      'Your down payment is still being checked. You can pay once it is confirmed.',
                      tone: NoticeTone.warn,
                    ),
                  ] else if (!d.paystack) ...[
                    const SizedBox(height: 12),
                    const Notice(
                      "Online payment isn't available right now. Please try again later, or contact us at info@tabitalpay.com.",
                      tone: NoticeTone.warn,
                    ),
                  ],
                  if (_error != null) ...[const SizedBox(height: 12), Notice(_error!, tone: NoticeTone.error)],
                ],
              ),
            ),
            PayBar(
              button: FilledButton.icon(
                key: const Key('pay-button'),
                onPressed: canPay ? () => _pay(d, quote: quote) : null,
                icon: _starting ? const ButtonSpinner() : const Icon(LucideIcons.lock, size: 18),
                label: Text(
                  _starting
                      ? 'Opening secure checkout…'
                      : charge != null && charge > 0
                      ? 'Pay ${formatPesewas(charge)}'
                      : 'Pay',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
