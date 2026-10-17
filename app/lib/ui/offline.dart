import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_scope.dart';
import 'vault.dart';

final _when = DateFormat('d MMM, HH:mm', 'en_US');

/// "You're offline", with when the saved copy was last updated (G13).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.cachedAt});
  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) => Note(
    "You're offline. Showing your plans as last updated ${_when.format(cachedAt)}. Pull down to refresh. "
    'Paying needs a connection.',
    key: const Key('offline-banner'),
    title: 'Last updated ${_when.format(cachedAt)}',
    icon: LucideIcons.wifiOff,
    tone: NoteTone.warn,
  );
}

/// Rebuilds with whether the app can reach Tabital (the last request got an answer).
class OnlineBuilder extends StatelessWidget {
  const OnlineBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, bool online) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AppScope.of(context).customer.api.online,
    builder: (context, online, _) => builder(context, online),
  );
}

/// Shown above a pay, checkout, defer or report button while offline, with a way to check again.
class OfflineActionNote extends StatelessWidget {
  const OfflineActionNote({super.key, this.what = 'pay'});
  final String what;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Note(
      "You're offline. Connect to the internet to $what.",
      key: const Key('offline-action'),
      icon: LucideIcons.wifiOff,
      tone: NoteTone.warn,
      action: OutlinedButton(
        onPressed: () => AppScope.of(context).customer.ping(),
        child: const Text('Check again'),
      ),
    ),
  );
}
