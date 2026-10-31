import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import '../cards/card_models.dart';

/// Account tab (G10): limit, orders, cards, identity, notifications; Help and the support contact;
/// the legal pages with the Terms version the customer accepted (from the server); offers and
/// news; and the company line.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Consents? _consents;
  String? _status; // pending, approved, active, restricted (GET /customer/profile, U6)
  bool _savingMarketing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConsents();
      AppScope.of(context).customer.accountStatus().then((s) {
        if (mounted) setState(() => _status = s);
      }, onError: (_) {});
    });
  }

  Future<void> _loadConsents() async {
    try {
      final c = await AppScope.of(context).customer.consents();
      if (mounted) setState(() => _consents = c);
    } catch (_) {
      // The rest of the page works without it
    }
  }

  void _say(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(String url) async {
    try {
      await openLink(url);
    } catch (e) {
      _say(errorText(e, "Couldn't open the link."));
    }
  }

  Future<void> _setMarketing(bool on) async {
    setState(() => _savingMarketing = true);
    try {
      _say(await AppScope.of(context).customer.setMarketing(on));
      await _loadConsents();
    } catch (e) {
      _say(errorText(e, "Couldn't save that. Please try again."));
    } finally {
      if (mounted) setState(() => _savingMarketing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const external = Icon(LucideIcons.externalLink, size: 16, color: Tp.muted);
    final c = _consents;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: pagePadding,
        children: [
          if (_status != null) ...[_StatusCard(_status!), const SizedBox(height: Tp.s3)],
          VCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Lined([
              ListRow(icon: LucideIcons.wallet, label: 'Your limit', onTap: () => context.go('/account/limit')),
              ListRow(icon: LucideIcons.package, label: 'My orders', onTap: () => context.go('/account/orders')),
              ListRow(
                key: const Key('account-cards'),
                icon: LucideIcons.creditCard,
                label: 'Cards and autopay',
                onTap: () => context.go('/account/cards'),
              ),
              ListRow(icon: LucideIcons.scanFace, label: 'Verify your identity', onTap: () => context.go('/account/identity')),
              ListRow(key: const Key('account-documents'), icon: LucideIcons.fileUp, label: 'Upload documents', onTap: () => context.go('/account/identity/documents')),
              ListRow(icon: LucideIcons.bell, label: 'Notifications', onTap: () => context.push('/notifications')),
            ]),
          ),
          const SectionTitle('Help'),
          VCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Lined([
              ListRow(
                key: const Key('account-help'),
                icon: LucideIcons.lifeBuoy,
                label: 'Help centre',
                trailing: external,
                onTap: () => _open(AppConfig.helpUrl),
              ),
              const ListRow(icon: LucideIcons.mail, label: 'Contact us', trailing: Text(AppConfig.supportEmail)),
            ]),
          ),
          const SectionTitle('Legal and privacy'),
          VCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Lined([
              ListRow(
                icon: LucideIcons.fileText,
                label: 'Terms and Conditions',
                trailing: external,
                onTap: () => _open(AppConfig.termsUrl),
              ),
              ListRow(
                icon: LucideIcons.shieldCheck,
                label: 'Privacy Policy',
                trailing: external,
                onTap: () => _open(AppConfig.privacyUrl),
              ),
              if (c != null)
                SwitchListTile(
                  key: const Key('account-marketing'),
                  contentPadding: EdgeInsets.zero,
                  value: c.marketing,
                  activeThumbColor: Tp.navy,
                  onChanged: _savingMarketing ? null : _setMarketing,
                  title: Text(
                    'Offers and news',
                    style: t.bodyMedium?.copyWith(color: Tp.navy, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Payment reminders and receipts come either way.', style: t.bodySmall),
                ),
            ]),
          ),
          if (c?.termsVersion != null) ...[
            const SizedBox(height: Tp.s2),
            Text(
              'You accepted the Terms version ${c!.termsVersion}'
              '${c.acceptedAt == null ? '' : ' on ${formatDate(c.acceptedAt)}'}.',
              key: const Key('account-terms-version'),
              style: t.bodySmall,
            ),
          ],
          const SizedBox(height: Tp.s4),
          VCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListRow(
              icon: LucideIcons.logOut,
              label: 'Sign out',
              color: Tp.error,
              trailing: const SizedBox.shrink(),
              onTap: () => AppScope.of(context).auth.signOut(),
            ),
          ),
          const SizedBox(height: Tp.s6),
          const Center(child: TabitalMark(height: 22, withName: true, nameColor: Tp.navy)),
          const SizedBox(height: Tp.s2),
          Text(AppConfig.legalLine, key: const Key('account-legal'), textAlign: TextAlign.center, style: t.bodySmall),
          Text(AppConfig.supportEmail, textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ),
    );
  }
}

/// The account's state, with what it means for the customer (U6).
class _StatusCard extends StatelessWidget {
  const _StatusCard(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (chip, text) = switch (status) {
      'pending' => (
        const VChip('Waiting for verification', icon: LucideIcons.clock, tone: NoteTone.warn),
        'Add your details and documents in Verify identity. You can buy once your account is approved.',
      ),
      'approved' || 'active' => (const VChip('Approved', icon: LucideIcons.badgeCheck, tone: NoteTone.success), null),
      'restricted' => (
        const VChip('Restricted', icon: LucideIcons.circleAlert, tone: NoteTone.error),
        'You can pay your plans, but new purchases are paused. Contact us to find out more.',
      ),
      _ => (VChip(status), null),
    };
    return VCard(
      key: const Key('account-status'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your account', style: t.titleSmall)),
              chip,
            ],
          ),
          if (text != null) ...[const SizedBox(height: 6), Text(text, style: t.bodySmall)],
          if (status == 'pending') ...[
            const SizedBox(height: Tp.s2),
            OutlinedButton(onPressed: () => context.go('/account/identity'), child: const Text('Verify identity')),
          ],
        ],
      ),
    );
  }
}
