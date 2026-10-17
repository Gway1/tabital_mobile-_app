import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../plans/plan_models.dart';

/// The large next-payment card (prototype S4, `.next`): white, over the navy header.
/// Overdue shows a red border and the late fee as its own line.
class NextPaymentCard extends StatelessWidget {
  const NextPaymentCard({super.key, required this.next, required this.today});
  final NextDue next;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pay = next.payment;
    final plan = next.plan;
    final overdue = next.overdue(today);
    final days = pay.dueDate == null ? null : daysUntil(pay.dueDate!, today);
    final total = plan.schedule.length;
    final paid = plan.paidCount;
    final label = overdue ? 'Overdue payment' : 'Next payment';
    final dueText = '${overdue ? 'Was due' : 'Due'} ${formatDate(pay.dueDate)}';
    final chip = days == null
        ? null
        : overdue
        ? VChip('Overdue ${-days} day${days == -1 ? '' : 's'}', icon: LucideIcons.triangleAlert, tone: NoteTone.error)
        : VChip(_inDays(days), icon: LucideIcons.clock, tone: NoteTone.warn);

    return Semantics(
      container: true,
      label: '$label, ${formatPesewas(pay.amountDue)}, $dueText',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Tp.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: overdue ? Tp.error : Tp.line, width: overdue ? 1.5 : 1),
          boxShadow: const [BoxShadow(color: Color(0x2902163F), blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: .7, color: overdue ? Tp.error : Tp.muted)),
              const SizedBox(height: 6),
              Text(formatPesewas(pay.amountDue), key: const Key('next-amount'), style: t.displaySmall),
              const SizedBox(height: 2),
              Wrap(
                spacing: Tp.s2,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(dueText, key: const Key('next-due'), style: t.bodyMedium),
                  ?chip,
                ],
              ),
              if (pay.lateFee > 0 || pay.partPaid > 0)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Tp.surface2, borderRadius: BorderRadius.circular(Tp.radiusLg)),
                  child: Column(
                    children: [
                      VRow('Payment ${pay.number}', formatPesewas(pay.amount), size: 13),
                      if (pay.lateFee > 0)
                        VRow(
                          'Late fee',
                          formatPesewas(pay.lateFee),
                          size: 13,
                          valueColor: Tp.error,
                          valueKey: const Key('next-late-fee'),
                        ),
                      if (pay.partPaid > 0) VRow('Already paid', '− ${formatPesewas(pay.partPaid)}', size: 13),
                    ],
                  ),
                ),
              if (total > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: paid / total,
                    minHeight: 8,
                    backgroundColor: Tp.surface2,
                    valueColor: const AlwaysStoppedAnimation(Tp.navy2),
                  ),
                ),
                const SizedBox(height: 6),
                // Side by side when they fit (the prototype), one under the other on a narrow phone
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: Tp.s2,
                  runSpacing: 2,
                  children: [
                    Text(
                      '${plan.productName.isEmpty ? plan.planRef : plan.productName} · payment ${pay.number} of $total',
                      style: t.bodySmall,
                    ),
                    Text(
                      '${formatPesewas(plan.amountPaid)} of ${formatPesewas(plan.totalAmount)} paid',
                      key: const Key('next-progress'),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _inDays(int d) => d == 0
      ? 'Today'
      : d == 1
      ? 'Tomorrow'
      : 'In $d days';
}
