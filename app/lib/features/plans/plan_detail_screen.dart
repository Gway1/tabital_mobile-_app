import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
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
  Future<Plan>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppScope.of(context).customer.plan(widget.planId);
  }

  void _retry() => setState(() {
        _load = AppScope.of(context).customer.plan(widget.planId);
      });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = widget.today ?? DateTime(now.year, now.month, now.day);
    return FutureBuilder<Plan>(
      future: _load,
      builder: (context, snap) {
        final p = snap.data;
        // The next payment the server will charge
        final next = p != null && p.open ? p.schedule.where((s) => s.unpaid).firstOrNull : null;
        return Scaffold(
          appBar: AppBar(title: Text(p == null ? 'Plan' : (p.productName.isEmpty ? p.planRef : p.productName), overflow: TextOverflow.ellipsis)),
          body: switch (snap.connectionState) {
            ConnectionState.done when snap.hasError => ErrorPanel(message: errorText(snap.error, "Couldn't load this plan."), onRetry: _retry),
            ConnectionState.done => _body(p!, next, today),
            _ => const Center(child: CircularProgressIndicator()),
          },
          bottomNavigationBar: next == null
              ? null
              : PayBar(
                  amount: formatPesewas(next.amountDue),
                  caption: 'Payment ${next.number}',
                  button: FilledButton.icon(
                    key: const Key('plan-pay'),
                    onPressed: () => context.push('/plans/${p!.id}/pay'),
                    icon: const Icon(LucideIcons.lock, size: 18),
                    label: const Text('Pay'),
                  ),
                ),
        );
      },
    );
  }

  Widget _body(Plan p, ScheduleItem? next, DateTime today) {
    final t = Theme.of(context).textTheme;
    final total = p.schedule.length;
    return ListView(padding: pagePadding, children: [
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Paid', style: t.bodySmall)),
            Text('Left to pay', style: t.bodySmall),
          ]),
          Row(children: [
            Expanded(child: Text(formatPesewas(p.amountPaid), key: const Key('plan-paid'), style: moneyStyle(context, 20))),
            Text(formatPesewas(p.amountOutstanding), key: const Key('plan-left'), style: moneyStyle(context, 20)),
          ]),
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
          Row(children: [
            Expanded(
              child: Text(
                ['Pay in $total', if (p.planRef.isNotEmpty) 'Plan ${p.planRef}', if (p.merchantName.isNotEmpty) p.merchantName].join(' · '),
                style: t.bodySmall,
              ),
            ),
            if (p.status != 'active') StatusChip(p.status),
          ]),
        ]),
      ),
      const SectionTitle('Schedule'),
      VCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Lined([for (final s in p.schedule) _row(s, next, today)]),
      ),
      const SizedBox(height: 14),
      if (next != null && next.status == 'pending') ...[
        OutlinedButton.icon(
          key: const Key('plan-defer'),
          onPressed: () => context.push('/plans/${p.id}/defer?payment=${next.id}'),
          icon: const Icon(LucideIcons.calendarClock, size: 18),
          label: const Text('Move a payment back'),
        ),
        const SizedBox(height: Tp.s2),
      ],
      TextButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reporting a problem in the app is coming soon. For now, email ${AppConfig.supportEmail}.'),
        )),
        icon: const Icon(LucideIcons.flag, size: 18),
        label: const Text('Report a problem with this order'),
      ),
    ]);
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
              [if (s.lateFee > 0) 'Includes ${formatPesewas(s.lateFee)} late fee', if (moved) 'Moved from ${formatDate(s.originalDueDate)}']
                  .join(' · '),
              style: TextStyle(fontSize: 12, color: s.lateFee > 0 ? Tp.error : Tp.muted),
            )
          : null,
      amount: formatPesewas(s.paid ? s.amount : s.amountDue),
      trailing: overdue ? const Padding(padding: EdgeInsets.only(top: 2), child: VChip('Overdue', tone: NoteTone.error)) : null,
    );
  }
}
