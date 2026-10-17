import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../ui/offline.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'plan_models.dart';

/// Plans tab: active and completed plans.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  Future<({List<Plan> plans, DateTime? cachedAt})>? _load;

  ValueNotifier<int>? _changes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppScope.of(context).customer.plansView();
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
    final f = AppScope.of(context).customer.plansView();
    setState(() {
      _load = f;
    });
    await f.catchError((_) => (plans: <Plan>[], cachedAt: null));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: FutureBuilder<({List<Plan> plans, DateTime? cachedAt})>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorPanel(
              message: snap.error is ApiException ? (snap.error as ApiException).message : "Couldn't load your plans.",
              onRetry: _refresh,
            );
          }
          final plans = snap.data!.plans;
          final cachedAt = snap.data!.cachedAt;
          if (plans.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.listChecks,
              title: 'No plans yet',
              text: 'Your plans show here after your first purchase.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(Tp.s4),
              itemCount: plans.length + (cachedAt == null ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: Tp.s2),
              itemBuilder: (context, i) {
                if (cachedAt != null && i == 0) return OfflineBanner(cachedAt: cachedAt);
                final p = plans[cachedAt == null ? i : i - 1];
                return Card(
                  child: ListTile(
                    minTileHeight: 64,
                    title: Text(p.productName.isEmpty ? p.planRef : p.productName),
                    subtitle: Text('${p.paidCount} of ${p.schedule.length} paid · ${formatPesewas(p.amountOutstanding)} left'),
                    trailing: StatusChip(p.status),
                    onTap: () => context.push('/plans/${p.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
