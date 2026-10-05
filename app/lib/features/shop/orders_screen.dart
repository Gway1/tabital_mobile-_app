import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../pay/run_checkout.dart';
import 'shop_models.dart';

/// My orders. An order waits as "awaiting down payment" until Paystack confirms Payment 1
/// (D13); the customer can pay it again from here.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<Order>>? _load;
  int? _paying;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppScope.of(context).customer.orders();
  }

  Future<void> _refresh() async {
    final f = AppScope.of(context).customer.orders();
    setState(() {
      _load = f;
    });
    await f.catchError((_) => <Order>[]);
  }

  Future<void> _pay(Order o) async {
    if (_paying != null) return;
    setState(() => _paying = o.id);
    try {
      final start = await AppScope.of(context).customer.payOrder(o.id);
      if (!mounted) return;
      await runCheckout(context, start, agreed: o.dueNow, replace: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e, 'Could not start the payment. Please try again.'))));
      }
    } finally {
      if (mounted) setState(() => _paying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: FutureBuilder<List<Order>>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorPanel(message: errorText(snap.error, "Couldn't load your orders."), onRetry: _refresh);
          final orders = snap.data!;
          if (orders.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.package,
              title: 'No orders yet',
              text: 'Your orders show here after you buy.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(Tp.s4),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: Tp.s2),
              itemBuilder: (context, i) => _OrderCard(orders[i], paying: _paying == orders[i].id, onPay: () => _pay(orders[i])),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o, {required this.paying, required this.onPay});
  final Order o;
  final bool paying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = switch (o.status) {
      'approved' || 'completed' => 'paid',
      'rejected' || 'cancelled' => 'cancelled',
      _ => 'pending',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tp.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(o.productName, style: t.titleSmall)),
                StatusChip(tone, label: o.statusLabel),
              ],
            ),
            Text('${o.orderRef}${o.createdAt == null ? '' : ' · ${formatDate(o.createdAt)}'}', style: t.bodySmall),
            const SizedBox(height: Tp.s2),
            AmountRow('Total payable', formatPesewas(o.totalPayable)),
            if (o.awaitingDownPayment) ...[
              AmountRow('Due now (Payment 1)', formatPesewas(o.dueNow), strong: true),
              const SizedBox(height: Tp.s2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: paying ? null : onPay,
                  icon: paying ? const ButtonSpinner() : const Icon(LucideIcons.lock, size: 18),
                  label: Text('Pay ${formatPesewas(o.dueNow)}'),
                ),
              ),
            ],
            if (o.refundNote != null) ...[const SizedBox(height: Tp.s2), Notice(o.refundNote!, tone: NoticeTone.info)],
          ],
        ),
      ),
    );
  }
}
