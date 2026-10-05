import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/config.dart';
import '../../core/links.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';

/// Account tab: limit, orders, identity, help and the legal pages, as `.list-row`s.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    try {
      await openLink(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e, "Couldn't open the link."))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const external = Icon(LucideIcons.externalLink, size: 16, color: Tp.muted);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(padding: pagePadding, children: [
        VCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Lined([
            ListRow(icon: LucideIcons.wallet, label: 'Your limit', onTap: () => context.go('/account/limit')),
            ListRow(icon: LucideIcons.package, label: 'My orders', onTap: () => context.go('/account/orders')),
            ListRow(icon: LucideIcons.scanFace, label: 'Verify your identity', onTap: () => context.go('/account/identity')),
          ]),
        ),
        const SectionTitle('Help'),
        VCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Lined([
            ListRow(icon: LucideIcons.lifeBuoy, label: 'Help centre', trailing: external, onTap: () => _open(context, AppConfig.helpUrl)),
            const ListRow(icon: LucideIcons.mail, label: 'Contact us', trailing: Text(AppConfig.supportEmail)),
            ListRow(icon: LucideIcons.fileText, label: 'Terms and Conditions', trailing: external, onTap: () => _open(context, AppConfig.termsUrl)),
            ListRow(icon: LucideIcons.shieldCheck, label: 'Privacy Policy', trailing: external, onTap: () => _open(context, AppConfig.privacyUrl)),
          ]),
        ),
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
      ]),
    );
  }
}
