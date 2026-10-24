import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../identity/identity_models.dart';
import 'product_image.dart';
import 'shop_models.dart';

/// What checkout needs from the product page.
class CheckoutArgs {
  CheckoutArgs({required this.product, required this.options, required this.option, required this.quantity});
  final Product product;
  final PlanOptions options;
  final PlanOption option;
  final int quantity;
}

/// S6: the product, every plan side by side (today and the monthly amount), and the chosen
/// plan's full schedule, all priced by the server (prototype S6).
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.productId});
  final int productId;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Future<Product>? _product;
  Future<PlanOptions>? _options;
  IdentityStatus? _identity;
  int _quantity = 1;
  int? _chosen; // number of payments

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_product == null) {
      final customer = AppScope.of(context).customer;
      _product = customer.product(widget.productId);
      _price();
      customer.identity().then((s) {
        if (mounted) setState(() => _identity = s);
      }, onError: (_) {});
    }
  }

  void _price() {
    final f = AppScope.of(context).customer.planOptions(widget.productId, quantity: _quantity);
    setState(() {
      _options = f;
    });
    f.then((o) {
      if (!mounted) return;
      // Pay in 4 is the main plan; customers who can't use credit start on paying in full
      if (_chosen == null || o.option(_chosen!) == null) {
        final eligible = o.credit?.eligible ?? false;
        setState(
          () =>
              _chosen = (eligible ? o.option(4) : null)?.nPayments ?? o.option(1)?.nPayments ?? o.options.firstOrNull?.nPayments,
        );
      }
    }, onError: (_) {});
  }

  void _setQuantity(int q, int stock) {
    if (q < 1 || q > stock || q == _quantity) return;
    setState(() => _quantity = q);
    _price();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product>(
      future: _product,
      builder: (context, snap) {
        final p = snap.data;
        return Scaffold(
          appBar: AppBar(title: Text(p?.name ?? 'Product', overflow: TextOverflow.ellipsis)),
          body: switch (snap.connectionState) {
            // A product that's gone, or from a shop not approved yet, is "not available" (400/404, U7)
            ConnectionState.done
                when snap.hasError &&
                    snap.error is ApiException &&
                    const [400, 404].contains((snap.error as ApiException).status) =>
              EmptyState(
                key: const Key('product-unavailable'),
                icon: LucideIcons.packageX,
                title: "This product isn't available",
                text: (snap.error as ApiException).message,
                action: OutlinedButton(onPressed: () => context.go('/shop'), child: const Text('Back to the shop')),
              ),
            ConnectionState.done when snap.hasError => ErrorPanel(
              message: errorText(snap.error, "Couldn't load this product."),
              onRetry: () => setState(() {
                _product = AppScope.of(context).customer.product(widget.productId);
              }),
            ),
            ConnectionState.done => _body(p!),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }

  Widget _body(Product p) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<PlanOptions>(
      future: _options,
      builder: (context, snap) {
        final options = snap.data;
        final chosen = options == null || _chosen == null ? null : options.option(_chosen!);
        final pricing = snap.connectionState != ConnectionState.done;
        final needsIdentity = _identity != null && !_identity!.verified;
        final blocked = chosen != null && !chosen.available;
        final canContinue = chosen != null && !pricing && !blocked && !needsIdentity && p.inStock;

        return Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  SizedBox(height: 170, child: ProductImage(p.image, large: true)),
                  Padding(
                    padding: pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatPesewas(p.price), style: moneyStyle(context, 22)),
                                  Text(
                                    [
                                      if (p.merchantName.isNotEmpty) 'Sold by ${p.merchantName}',
                                      p.inStock ? '${p.stock} in stock' : 'Out of stock',
                                    ].join(' · '),
                                    style: t.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (p.inStock && p.stock > 1)
                              _Stepper(quantity: _quantity, onChange: (q) => _setQuantity(q, p.stock), max: p.stock),
                          ],
                        ),
                        if (p.description.isNotEmpty) ...[const SizedBox(height: 10), Text(p.description, style: t.bodyMedium)],
                        const SectionTitle('How would you like to pay?'),
                        if (pricing)
                          const Padding(
                            padding: EdgeInsets.all(Tp.s4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: Tp.s2),
                                Text('Pricing your plans…'),
                              ],
                            ),
                          )
                        else if (snap.hasError)
                          ErrorPanel(message: errorText(snap.error, "We couldn't price this product right now."), onRetry: _price)
                        else if (options != null) ...[
                          for (final o in options.options)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Tp.s2),
                              child: PlanOptionTile(
                                o,
                                selected: o.nPayments == _chosen,
                                onTap: () => setState(() => _chosen = o.nPayments),
                              ),
                            ),
                          const _ComingSoonTile(),
                          if (chosen != null) ...[const SectionTitle('Your schedule'), QuoteSchedule(chosen)],
                          const SizedBox(height: 10),
                          Text(
                            'Interest-free when you pay on time. Late fees and moving a payment are explained before you confirm.',
                            style: t.bodySmall,
                          ),
                        ],
                        if (needsIdentity) ...[
                          const SizedBox(height: 14),
                          Note(
                            'Verify your identity before you buy.',
                            tone: NoteTone.warn,
                            action: OutlinedButton(
                              onPressed: () => context.push('/account/identity'),
                              child: const Text('Verify now'),
                            ),
                          ),
                        ] else if (blocked) ...[
                          const SizedBox(height: 14),
                          Note(chosen.blockedReason ?? 'This plan is not available to you right now.', tone: NoteTone.warn),
                        ] else if (chosen != null &&
                            chosen.usesCredit &&
                            options?.credit != null &&
                            options!.credit!.eligible) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(LucideIcons.circleCheck, size: 16, color: Tp.success),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Within your available limit of ${formatPesewas(options.credit!.availableLimit)}',
                                  style: t.bodySmall?.copyWith(color: Tp.success),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PayBar(
              amount: chosen == null ? null : formatPesewas(chosen.dueNow),
              amountKey: const Key('due-today'),
              caption: 'Due today',
              button: FilledButton(
                key: const Key('continue'),
                onPressed: canContinue
                    ? () => context.push(
                        '/shop/product/${p.id}/checkout',
                        extra: CheckoutArgs(product: p, options: options!, option: chosen, quantity: _quantity),
                      )
                    : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.quantity, required this.onChange, required this.max});
  final int quantity;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Tp.surface,
      border: Border.all(color: Tp.line),
      borderRadius: BorderRadius.circular(Tp.radius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'One fewer',
          onPressed: quantity > 1 ? () => onChange(quantity - 1) : null,
          icon: const Icon(LucideIcons.minus, size: 18),
        ),
        Text('$quantity', key: const Key('quantity'), style: moneyStyle(context)),
        IconButton(
          tooltip: 'One more',
          onPressed: quantity < max ? () => onChange(quantity + 1) : null,
          icon: const Icon(LucideIcons.plus, size: 18),
        ),
      ],
    ),
  );
}

/// `.plan-opt`: a radio, the plan's name and what follows, and what's due today on the right.
class PlanOptionTile extends StatelessWidget {
  const PlanOptionTile(this.o, {super.key, required this.selected, required this.onTap});
  final PlanOption o;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sub = !o.available && o.blockedReason != null
        ? o.blockedReason!
        : o.installments == 0
        ? 'One payment today'
        : '${o.downPaymentPercentage.isEmpty ? '' : '${o.downPaymentPercentage}% '}today, '
              'then ${o.installments} × ${formatPesewas(o.installmentAmount)}';
    return Opacity(
      opacity: o.available ? 1 : .55,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: Key('plan-${o.nPayments}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Tp.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Tp.navy : Tp.line, width: selected ? 2 : 1.5),
            ),
            child: Row(
              children: [
                _Radio(on: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.label, style: t.titleSmall),
                      Text(sub, style: t.bodySmall?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: Tp.s2),
                Text(formatPesewas(o.dueNow), style: moneyStyle(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Opacity(
      opacity: .55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Tp.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Tp.line, width: 1.5),
        ),
        child: Row(
          children: [
            const _Radio(on: false),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('6 and 12 months', style: t.titleSmall),
                Text('Coming soon', style: t.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: on ? Tp.navy : Tp.line, width: 2),
    ),
    child: on
        ? Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: Tp.navy, shape: BoxShape.circle),
          )
        : null,
  );
}

/// A quoted schedule: Payment 1 today (gold), then each monthly payment, then the total payable.
/// [from] skips earlier payments (checkout lists Payment 1 on its own).
class QuoteSchedule extends StatelessWidget {
  const QuoteSchedule(this.option, {super.key, this.from = 1});
  final PlanOption option;
  final int from;

  @override
  Widget build(BuildContext context) {
    final lines = option.schedule.where((l) => l.number >= from).toList();
    return VCard(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        children: [
          Lined([
            for (final l in lines)
              if (l.number == 1)
                SchedRow(
                  number: 1,
                  state: SchedState.now,
                  title: option.usesCredit ? 'Payment 1, down payment' : 'Payment 1, full price',
                  sub: l.deliveryFee > 0
                      ? 'Today · ${formatPesewas(option.downPayment)} + ${formatPesewas(l.deliveryFee)} delivery'
                      : 'Today',
                  amount: formatPesewas(l.amount),
                )
              else
                SchedRow(
                  number: l.number,
                  title: 'Payment ${l.number}',
                  sub: formatDate(l.dueDate),
                  amount: formatPesewas(l.amount),
                ),
          ]),
          TotalRow('Total payable', formatPesewas(option.totalPayable), valueKey: const Key('schedule-total')),
        ],
      ),
    );
  }
}
