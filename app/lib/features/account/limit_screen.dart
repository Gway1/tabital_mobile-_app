import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../plans/plan_models.dart';

/// S14: the spending limit and how it changes (`GET /customer/credit`).
class LimitScreen extends StatefulWidget {
  const LimitScreen({super.key});

  @override
  State<LimitScreen> createState() => _LimitScreenState();
}

class _LimitScreenState extends State<LimitScreen> {
  Future<CreditSummary?>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppScope.of(context).customer.credit();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your limit')),
      body: FutureBuilder<CreditSummary?>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final c = snap.data;
          if (snap.hasError || c == null) {
            return ErrorPanel(
              message: errorText(snap.error, "Couldn't load your limit."),
              onRetry: () => setState(() {
                _load = AppScope.of(context).customer.credit();
              }),
            );
          }
          final share = c.creditLimit <= 0 ? 0.0 : (c.availableLimit / c.creditLimit).clamp(0.0, 1.0);
          return ListView(
            padding: pagePadding,
            children: [
              VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available to spend', style: t.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      c.eligible ? formatPesewas(c.availableLimit) : 'Not available yet',
                      key: const Key('limit-available'),
                      style: moneyStyle(context, c.eligible ? 30 : 20),
                    ),
                    const SizedBox(height: 12),
                    // The bar only shows the proportion; both figures come from the server
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            Expanded(
                              flex: ((1 - share) * 1000).round(),
                              child: Container(color: Tp.navy2),
                            ),
                            Expanded(
                              flex: (share * 1000).round(),
                              child: Container(color: Tp.gold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: Tp.navy2, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 6),
                        Text('In plans', style: t.bodySmall?.copyWith(fontSize: 12)),
                        const SizedBox(width: 14),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: Tp.gold, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 6),
                        Text('Available', style: t.bodySmall?.copyWith(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    VRow('Total limit', formatPesewas(c.creditLimit)),
                    if (c.tier.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Tier')),
                            VChip(c.tier[0].toUpperCase() + c.tier.substring(1)),
                          ],
                        ),
                      ),
                    if (!c.eligible && c.reasons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Note(c.reasons.join('\n'), tone: NoteTone.warn),
                    ],
                  ],
                ),
              ),
              const SectionTitle('How it grows'),
              const VCard(
                child: StepsList([
                  (LucideIcons.trendingUp, 'Each plan paid on time adds to your limit', IconTone.ok),
                  (LucideIcons.trendingDown, 'A late payment lowers it', IconTone.error),
                  (LucideIcons.lock, 'While a payment is overdue, new plans are paused', IconTone.navy),
                ]),
              ),
              const SizedBox(height: 10),
              Text('Your limit is checked against the full price of what you buy.', style: t.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
