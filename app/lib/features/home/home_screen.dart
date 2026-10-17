import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/offline.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../plans/customer_repository.dart';
import '../plans/plan_models.dart';
import 'next_payment_card.dart';

/// S4: what do I owe next, and when? A navy greeting, the next-payment card over it, the limit,
/// the plans, and a sticky pay bar (prototype S4).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.today});

  /// Fixed "today" for tests.
  final DateTime? today;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<HomeData>? _load;
  ValueNotifier<int>? _changes;
  int _unread = 0; // the bell's dot

  Future<void> _loadUnread() async {
    try {
      final n = await AppScope.of(context).customer.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // The bell just shows no dot; Home itself still loads
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_load == null) {
      _load = AppScope.of(context).customer.home();
      _loadUnread();
    }
    // Reload after a payment or a new order, since this tab stays alive
    final changes = AppScope.of(context).customer.changes;
    if (_changes != changes) {
      _changes?.removeListener(_refresh);
      _changes = changes..addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _changes?.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final f = AppScope.of(context).customer.home();
    _loadUnread();
    setState(() {
      _load = f;
    });
    await f.catchError((_) => HomeData(customerName: '', credit: null, plans: const []));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = widget.today ?? DateTime(now.year, now.month, now.day);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // light icons on the navy header
      child: FutureBuilder<HomeData>(
        future: _load,
        builder: (context, snap) {
          final data = snap.data;
          final next = data?.nextDue;
          final overdue = next?.overdue(today) ?? false;
          return Scaffold(
            body: switch (snap.connectionState) {
              ConnectionState.done when snap.hasError => SafeArea(
                child: ErrorPanel(message: errorText(snap.error, "Couldn't load your account."), onRetry: _refresh),
              ),
              ConnectionState.done => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(data: data!, next: next, overdue: overdue, unread: _unread),
                    Transform.translate(
                      offset: const Offset(0, -58),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Tp.s4),
                        child: next != null ? NextPaymentCard(next: next, today: today) : const _NothingDue(),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -58),
                      child: Padding(
                        padding: pagePadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data.cachedAt != null) ...[
                              const SizedBox(height: Tp.s4),
                              OfflineBanner(cachedAt: data.cachedAt!),
                            ],
                            if (overdue) ...[
                              const SizedBox(height: Tp.s4),
                              const Note(
                                'Pay as soon as you can: another late fee is added if a payment stays unpaid. '
                                "While a payment is overdue you can't start a new plan.",
                                tone: NoteTone.warn,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => context.push('/plans/${next!.plan.id}/pay?mode=part'),
                                  child: const Text('Pay part of it'),
                                ),
                              ),
                            ],
                            if (data.credit != null) ...[const SectionTitle('Your limit'), _LimitCard(data.credit!)],
                            if (data.openPlans.isNotEmpty) ...[
                              const SectionTitle('Your plans'),
                              VCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                child: Lined([for (final p in data.openPlans) _PlanMini(p, today: today)]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
            // Sticky pay bar: Pay is always one tap away when something is due
            bottomNavigationBar: next == null
                ? null
                : OnlineBuilder(
                    // Offline, the bar never shows a saved amount and can't be pressed (G13)
                    builder: (context, online) => online && data!.cachedAt == null
                        ? PayBar(
                            amount: formatPesewas(next.payment.amountDue),
                            amountKey: const Key('pay-bar-amount'),
                            caption: overdue ? 'Overdue' : 'Due ${_short(next.payment.dueDate)}',
                            button: FilledButton.icon(
                              key: const Key('pay-bar'),
                              onPressed: () => context.push('/plans/${next.plan.id}/pay'),
                              icon: const Icon(LucideIcons.lock, size: 18),
                              label: const Text('Pay now'),
                            ),
                          )
                        : const PayBar(
                            button: FilledButton(
                              key: Key('pay-bar'),
                              onPressed: null,
                              child: Text("You're offline: connect to pay"),
                            ),
                          ),
                  ),
          );
        },
      ),
    );
  }

  static String _short(DateTime? d) {
    final s = formatDate(d);
    return s.length > 5 ? s.substring(0, s.length - 5) : s; // "3 Nov 2026" -> "3 Nov"
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.next, required this.overdue, required this.unread});
  final HomeData data;
  final NextDue? next;
  final bool overdue;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = data.customerName.trim().split(RegExp(r'\s+')).first;
    final sub = overdue
        ? 'A payment needs your attention'
        : next != null
        ? 'Your plans are on track'
        : 'Welcome to Tabital Pay';
    return Container(
      color: Tp.navy,
      padding: EdgeInsets.fromLTRB(Tp.s4, MediaQuery.paddingOf(context).top + 14, Tp.s4, 70),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first.isEmpty ? 'Hello' : 'Hello, $first', style: t.titleLarge?.copyWith(color: Tp.onNavy, fontSize: 20)),
                const SizedBox(height: 2),
                Text(sub, style: t.bodySmall?.copyWith(color: Tp.onNavyMuted)),
              ],
            ),
          ),
          // The prototype's bell, with a gold dot when there are unread messages
          IconButton(
            key: const Key('bell'),
            tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(LucideIcons.bell, color: Tp.onNavy, size: 22),
                if (unread > 0)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      key: const Key('bell-dot'),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Tp.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Tp.navy, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NothingDue extends StatelessWidget {
  const _NothingDue();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Tp.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Tp.line),
      boxShadow: const [BoxShadow(color: Color(0x2902163F), blurRadius: 28, offset: Offset(0, 10))],
    ),
    child: EmptyState(
      icon: LucideIcons.shoppingBag,
      title: 'Nothing to pay right now',
      text: 'Find something you need and pay in 2, 3 or 4.',
      action: OutlinedButton(onPressed: () => context.go('/shop'), child: const Text('Go to the shop')),
    ),
  );
}

class _LimitCard extends StatelessWidget {
  const _LimitCard(this.c);
  final CreditSummary c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tp.radiusLg),
        onTap: () => context.push('/account/limit'),
        child: VCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Tp.navySoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.wallet, size: 20, color: Tp.navy2),
              ),
              const SizedBox(width: Tp.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.eligible) ...[
                      Text(
                        '${formatPesewas(c.availableLimit)} available',
                        key: const Key('available-limit'),
                        style: moneyStyle(context),
                      ),
                      Text('of ${formatPesewas(c.creditLimit)} · grows when you pay on time', style: t.bodySmall),
                    ] else ...[
                      Text('Not available yet', style: moneyStyle(context)),
                      if (c.reasons.isNotEmpty) Text(c.reasons.first, style: t.bodySmall),
                    ],
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18, color: Tp.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanMini extends StatelessWidget {
  const _PlanMini(this.p, {required this.today});
  final Plan p;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final left = p.schedule.where((s) => s.unpaid).length;
    final late = p.schedule.any(
      (s) => s.status == 'overdue' || (s.unpaid && s.dueDate != null && daysUntil(s.dueDate!, today) < 0),
    );
    return InkWell(
      onTap: () => context.push('/plans/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Tp.surface2, borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.package, size: 22, color: Tp.navy2),
            ),
            const SizedBox(width: Tp.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.productName.isEmpty ? p.planRef : p.productName, style: t.titleSmall),
                  Text('Pay in ${p.schedule.length} · $left payment${left == 1 ? '' : 's'} left', style: t.bodySmall),
                ],
              ),
            ),
            if (p.status == 'defaulted' || late)
              const VChip('Overdue', icon: LucideIcons.triangleAlert, tone: NoteTone.error)
            else
              const VChip('On track', icon: LucideIcons.check, tone: NoteTone.success),
          ],
        ),
      ),
    );
  }
}
