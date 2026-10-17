import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'card_models.dart';

/// Saved cards and autopay (G8), as on the web make-payment screen. Paystack saves a card after a
/// card payment. Autopay is opt-in, with a confirm first; removing a card stops its autopay.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<SavedCard>? _cards;
  String? _error;
  int? _busy; // the card being changed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final cards = await AppScope.of(context).customer.savedCards();
      if (mounted) setState(() => _cards = cards);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, "Couldn't load your cards."));
    }
  }

  void _say(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm({required String title, required String message, required String action, bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Tp.error, foregroundColor: Tp.onNavy) : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _toggleAutopay(SavedCard c) async {
    final on = !c.autopay;
    if (on &&
        !await _confirm(
          title: 'Turn on autopay?',
          message: "We'll charge card ending ${c.last4} on each due date, and try again for a few days if a charge fails.",
          action: 'Turn on autopay',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = c.id);
    try {
      _say(await AppScope.of(context).customer.setAutopay(c.id, on));
      await _load();
    } catch (e) {
      _say(errorText(e, 'Could not update autopay'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _remove(SavedCard c) async {
    if (!await _confirm(
      title: 'Remove card ending ${c.last4}?',
      message: 'Autopay will stop for this card.',
      action: 'Remove card',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = c.id);
    try {
      await AppScope.of(context).customer.removeCard(c.id);
      _say('Card removed');
      await _load();
    } catch (e) {
      _say(errorText(e, 'Could not remove the card'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cards = _cards;
    return Scaffold(
      appBar: AppBar(title: const Text('Cards and autopay')),
      body: _error != null
          ? ErrorPanel(message: _error!, onRetry: _load)
          : cards == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: pagePadding,
                children: [
                  if (cards.isEmpty)
                    const EmptyState(
                      icon: LucideIcons.creditCard,
                      title: 'No saved cards',
                      text: 'When you pay by card, Paystack can save it so you can turn on autopay.',
                    )
                  else
                    VCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Lined([for (final c in cards) _cardRow(c)]),
                    ),
                  const SizedBox(height: 12),
                  const Note(
                    'With autopay on, we charge your card on each due date, and try again for a few days if a charge fails. '
                    'You can turn it off at any time.',
                    icon: LucideIcons.refreshCw,
                  ),
                  const SizedBox(height: 10),
                  Text('Cards are kept by Paystack. Tabital never sees your full card number.', style: t.bodySmall),
                ],
              ),
            ),
    );
  }

  Widget _cardRow(SavedCard c) {
    final t = Theme.of(context).textTheme;
    final busy = _busy == c.id;
    return Padding(
      key: Key('card-${c.id}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.creditCard, size: 20, color: Tp.navy2),
              const SizedBox(width: Tp.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.name} •••• ${c.last4}', style: t.titleSmall),
                    Text(
                      [if (c.bank.isNotEmpty) c.bank, if (c.expiry != null) 'expires ${c.expiry}'].join(' · '),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              c.autopay ? const VChip('Autopay on', icon: LucideIcons.check, tone: NoteTone.success) : const VChip('Autopay off'),
            ],
          ),
          const SizedBox(height: Tp.s2),
          // Wraps on a narrow phone or with large text instead of overflowing
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Tp.s2,
            children: [
              if (c.reusable || c.autopay)
                TextButton(
                  key: Key('autopay-${c.id}'),
                  onPressed: busy ? null : () => _toggleAutopay(c),
                  child: Text(c.autopay ? 'Turn off autopay' : 'Turn on autopay'),
                )
              else
                Text("This card can't be charged automatically.", style: t.bodySmall),
              TextButton(
                key: Key('remove-${c.id}'),
                style: TextButton.styleFrom(foregroundColor: Tp.error),
                onPressed: busy ? null : () => _remove(c),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
