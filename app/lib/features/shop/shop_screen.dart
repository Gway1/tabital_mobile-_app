import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../identity/identity_models.dart';
import '../plans/plan_models.dart';
import 'product_image.dart';
import 'shop_models.dart';

/// S5: products from partner shops, with the customer's spending limit up front and the
/// server's Pay in 4 teaser on each card.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _category = '';
  List<String> _categories = const [];

  final List<Product> _products = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  IdentityStatus? _identity;
  CreditSummary? _credit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
      _loadStatus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final customer = AppScope.of(context).customer;
    // The banner is a hint only: the server checks identity and the limit again at checkout
    customer.identity().then((s) {
      if (mounted) setState(() => _identity = s);
    }, onError: (_) {});
    customer.credit().then((c) {
      if (mounted) setState(() => _credit = c);
    }, onError: (_) {});
    customer.categories().then((c) {
      if (mounted) setState(() => _categories = c);
    }, onError: (_) {});
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppScope.of(context).customer.products(search: _search.text, category: _category);
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(page.products);
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, "Couldn't load the shop."));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await AppScope.of(context).customer.products(page: _page + 1, search: _search.text, category: _category);
      if (!mounted) return;
      setState(() {
        _products.addAll(page.products);
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } catch (_) {
      // Keep what's shown; the button stays for another try
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            tooltip: 'My orders',
            icon: const Icon(LucideIcons.package, size: 22),
            onPressed: () => context.go('/account/orders'),
          ),
          const SizedBox(width: Tp.s2),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadStatus();
          await _reload();
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Tp.s4),
              sliver: SliverList.list(
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.search, size: 18, color: Tp.muted),
                      hintText: 'Search phones, laptops, appliances',
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  if (_categories.isNotEmpty)
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        children: [
                          for (final c in ['', ..._categories])
                            Padding(
                              padding: const EdgeInsets.only(right: Tp.s2),
                              child: _Pill(
                                label: c.isEmpty ? 'All' : c,
                                on: _category == c,
                                onTap: () {
                                  setState(() => _category = c);
                                  _reload();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: Tp.s2),
                  if (_identity != null && !_identity!.verified) ...[
                    Note(
                      'Verify your identity with your Ghana Card and a selfie before you buy. It takes about 2 minutes.',
                      title: 'Verify your identity to shop',
                      tone: NoteTone.warn,
                      action: OutlinedButton(onPressed: () => context.push('/account/identity'), child: const Text('Verify now')),
                    ),
                    const SizedBox(height: 12),
                  ] else if (_credit != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _credit!.eligible
                          ? Text.rich(
                              TextSpan(
                                style: t.bodySmall,
                                children: [
                                  const TextSpan(text: 'You can spend up to '),
                                  TextSpan(
                                    text: formatPesewas(_credit!.availableLimit),
                                    style: const TextStyle(color: Tp.navy, fontWeight: FontWeight.w700),
                                  ),
                                  const TextSpan(text: ' on a plan'),
                                ],
                              ),
                              key: const Key('shop-limit'),
                            )
                          : Text(
                              _credit!.reasons.isNotEmpty ? _credit!.reasons.first : 'You can still pay in full.',
                              style: t.bodySmall,
                            ),
                    ),
                ],
              ),
            ),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorPanel(message: _error!, onRetry: _reload),
              )
            else if (_products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: LucideIcons.searchX, title: 'No products found', text: 'Try another category or search.'),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Tp.s4),
                // Two cards a row (`.grid2`); each row is as tall as its taller card, so long text never overflows
                sliver: SliverList.separated(
                  itemCount: (_products.length + 1) ~/ 2,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, row) => IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ProductCard(_products[row * 2])),
                        const SizedBox(width: 10),
                        Expanded(
                          child: row * 2 + 1 < _products.length ? _ProductCard(_products[row * 2 + 1]) : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(Tp.s4),
                sliver: SliverToBoxAdapter(
                  child: _page < _totalPages
                      ? OutlinedButton(
                          onPressed: _loadingMore ? null : _more,
                          child: Text(_loadingMore ? 'Loading…' : 'Show more'),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `.cats span`: a category pill, navy when chosen.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: on,
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Tp.navy : Tp.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Tp.navy : Tp.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Tp.onNavy : Tp.navy2),
        ),
      ),
    ),
  );
}

/// `.prod`: picture, name, price and the server's Pay in 4 teaser.
class _ProductCard extends StatelessWidget {
  const _ProductCard(this.p);
  final Product p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sp = p.split;
    return Material(
      color: Tp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tp.radiusLg),
        side: const BorderSide(color: Tp.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/shop/product/${p.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 108, child: ProductImage(p.image)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(formatPesewas(p.price), style: moneyStyle(context)),
                  if (!p.inStock)
                    Text('Out of stock', style: t.bodySmall?.copyWith(fontSize: 12, color: Tp.error))
                  else if (sp != null && sp.installments > 0)
                    Text(
                      '${formatPesewas(sp.downPayment)} today${sp.deliveryFee > 0 ? ' + delivery' : ''}, '
                      'then ${sp.installments} × ${formatPesewas(sp.installmentAmount)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Tp.navy2, height: 1.35),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
