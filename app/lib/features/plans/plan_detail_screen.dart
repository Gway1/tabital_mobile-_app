import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/offline.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../support/support_models.dart';
import 'plan_models.dart';

/// S10: what's paid, what's left, the full schedule, and the actions (prototype S10).
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.planId, this.today});
  final int planId;

  /// Fixed "today" for tests.
  final DateTime? today;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  Future<({Plan plan, DateTime? cachedAt})>? _load;
  Dispute? _dispute; // an open report on this plan: its payments are paused

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_load == null) {
      _load = AppScope.of(context).customer.planView(widget.planId);
      _loadDispute();
    }
  }

  // The plan response doesn't say it's paused, so the open report is read from the disputes list
  Future<void> _loadDispute() async {
    try {
      final all = await AppScope.of(context).customer.disputes();
      if (mounted) setState(() => _dispute = all.where((d) => d.planId == widget.planId && d.open).firstOrNull);
    } catch (_) {
      // Without it the screen still works; the server enforces the pause
    }
  }

  void _retry() => setState(() {
    _load = AppScope.of(context).customer.planView(widget.planId);
    _loadDispute();
  });

  Future<void> _report(Plan p) async {
    final sent = await context.push<bool>('/plans/${p.id}/report');
    if (sent == true && mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = widget.today ?? DateTime(now.year, now.month, now.day);
    return FutureBuilder<({Plan plan, DateTime? cachedAt})>(
      future: _load,
      builder: (context, snap) {
        final p = snap.data?.plan;
        final cachedAt = snap.data?.cachedAt;
        // The next payment the server will charge
        final next = p != null && p.open ? p.schedule.where((s) => s.unpaid).firstOrNull : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              p == null ? 'Plan' : (p.productName.isEmpty ? p.planRef : p.productName),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: switch (snap.connectionState) {
            ConnectionState.done when snap.hasError => ErrorPanel(
              message: errorText(snap.error, "Couldn't load this plan."),
              onRetry: _retry,
            ),
            ConnectionState.done => _body(p!, next, today, cachedAt),
            _ => const Center(child: CircularProgressIndicator()),
          },
          bottomNavigationBar: next == null
              ? null
              : OnlineBuilder(
                  // Offline, never a saved amount on the pay bar, and no paying (G13)
                  builder: (context, online) => online && cachedAt == null
                      ? PayBar(
                          amount: formatPesewas(next.amountDue),
                          caption: 'Payment ${next.number}',
                          button: FilledButton.icon(
                            key: const Key('plan-pay'),
                            onPressed: () => context.push('/plans/${p!.id}/pay'),
                            icon: const Icon(LucideIcons.lock, size: 18),
                            label: const Text('Pay'),
                          ),
                        )
                      : const PayBar(
                          button: FilledButton(
                            key: Key('plan-pay'),
                            onPressed: null,
                            child: Text("You're offline: connect to pay"),
                          ),
                        ),
                ),
        );
      },
    );
  }

  Widget _body(Plan p, ScheduleItem? next, DateTime today, DateTime? cachedAt) {
    final offline = cachedAt != null;
    final t = Theme.of(context).textTheme;
    final total = p.schedule.length;
    return ListView(
      padding: pagePadding,
      children: [
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Paid', style: t.bodySmall)),
                  Text('Left to pay', style: t.bodySmall),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(formatPesewas(p.amountPaid), key: const Key('plan-paid'), style: moneyStyle(context, 20)),
                  ),
                  Text(formatPesewas(p.amountOutstanding), key: const Key('plan-left'), style: moneyStyle(context, 20)),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: p.paidCount / total,
                    minHeight: 8,
                    backgroundColor: Tp.surface2,
                    valueColor: const AlwaysStoppedAnimation(Tp.navy2),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        'Pay in $total',
                        if (p.planRef.isNotEmpty) 'Plan ${p.planRef}',
                        if (p.merchantName.isNotEmpty) p.merchantName,
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                  ),
                  if (p.status != 'active') StatusChip(p.status),
                ],
              ),
            ],
          ),
        ),
        if (offline) ...[const SizedBox(height: 12), OfflineBanner(cachedAt: cachedAt)],
        if (_dispute != null) ...[
          const SizedBox(height: 12),
          Note(
            "We're looking into the problem you reported (${_dispute!.reasonLabel.toLowerCase()}). "
            "Your remaining payments are paused, with no late fees, until it's resolved"
            '${_dispute!.respondBy == null ? '' : ', usually by ${formatDate(_dispute!.respondBy)}'}.',
            key: const Key('plan-paused'),
            title: 'Payments paused',
            icon: LucideIcons.shieldCheck,
          ),
        ],
        const SectionTitle('Schedule'),
        VCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Lined([for (final s in p.schedule) _row(s, next, today)]),
        ),
        const SizedBox(height: 14),
        // The deferment rules the server enforces too (§4): only the next payment, still upcoming,
        // with no late fee, never Payment 1, and not while the plan is paused
        if (!offline && next != null && next.status == 'pending' && next.number != 1 && next.lateFee == 0 && _dispute == null) ...[
          OutlinedButton.icon(
            key: const Key('plan-defer'),
            onPressed: () => context.push('/plans/${p.id}/defer?payment=${next.id}'),
            icon: const Icon(LucideIcons.calendarClock, size: 18),
            label: const Text('Move a payment back'),
          ),
          const SizedBox(height: Tp.s2),
        ],
        // Buyer protection (G5): only an active plan with no open report
        if (!offline && p.status == 'active' && _dispute == null)
          TextButton.icon(
            key: const Key('plan-report'),
            onPressed: () => _report(p),
            icon: const Icon(LucideIcons.flag, size: 18),
            label: const Text('Report a problem with this order'),
          ),
      ],
    );
  }

  Widget _row(ScheduleItem s, ScheduleItem? next, DateTime today) {
    final isNext = next != null && s.id == next.id;
    final days = s.dueDate == null ? null : daysUntil(s.dueDate!, today);
    final overdue = s.status == 'overdue' || (s.unpaid && days != null && days < 0);
    final title = s.number == 1 ? 'Payment 1, down payment' : 'Payment ${s.number}';
    final String sub;
    if (s.paid) {
      sub = s.paidDate == null ? 'Paid' : 'Paid ${formatDate(s.paidDate)}';
    } else if (s.status == 'pending_verification') {
      sub = 'Being checked';
    } else {
      final when = isNext && days != null ? ' · ${daysText(days)}' : '';
      sub = '${overdue ? 'Was due' : 'Due'} ${formatDate(s.dueDate)}$when';
    }
    final moved = s.originalDueDate != null && s.dueDate != null && s.originalDueDate != s.dueDate;
    return SchedRow(
      number: s.number,
      state: s.paid ? SchedState.paid : (isNext ? SchedState.now : SchedState.normal),
      title: title,
      sub: sub,
      subWidget: (s.lateFee > 0 || moved)
          ? Text(
              [
                if (s.lateFee > 0) 'Includes ${formatPesewas(s.lateFee)} late fee',
                if (moved) 'Moved from ${formatDate(s.originalDueDate)}',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: s.lateFee > 0 ? Tp.error : Tp.muted),
            )
          : null,
      amount: formatPesewas(s.paid ? s.amount : s.amountDue),
      trailing: overdue
          ? const Padding(
              padding: EdgeInsets.only(top: 2),
              child: VChip('Overdue', tone: NoteTone.error),
            )
          : null,
    );
  }
}
