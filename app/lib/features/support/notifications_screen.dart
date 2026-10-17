import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'support_models.dart';

/// Notifications (G7): the in-app messages the server sends (payment reminders, identity
/// updates), newest first. Opening one marks it read and goes to the screen it's about.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  String? _error;
  int _page = 1;
  bool _more = false;
  bool _loadingMore = false;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await AppScope.of(context).customer.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _page = 1;
        _more = items.length >= _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, "Couldn't load your notifications."));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await AppScope.of(context).customer.notifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items = [...?_items, ...next];
        _page++;
        _more = next.length >= _pageSize;
      });
    } catch (_) {
      // Keep what's shown; the button stays for another try
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(AppNotification n) async {
    final customer = AppScope.of(context).customer;
    final route = appRouteForLink(n.link);
    if (!n.read) {
      setState(() => _items = [for (final x in _items!) x.id == n.id ? x.copyWith(read: true) : x]);
      customer.markNotificationRead(n.id).catchError((_) {}); // shown read at once; the server catches up
    }
    if (route != null && mounted) context.push(route);
  }

  Future<void> _markAll() async {
    try {
      await AppScope.of(context).customer.markAllNotificationsRead();
      if (mounted) setState(() => _items = [for (final x in _items!) x.copyWith(read: true)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e, "Couldn't mark them as read."))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final unread = items?.where((n) => !n.read).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0) TextButton(key: const Key('mark-all-read'), onPressed: _markAll, child: const Text('Mark all as read')),
          const SizedBox(width: Tp.s2),
        ],
      ),
      body: _error != null
          ? ErrorPanel(message: _error!, onRetry: _load)
          : items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const EmptyState(
              icon: LucideIcons.bellOff,
              title: 'No notifications yet',
              text: 'Payment reminders and updates about your account show here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: pagePadding,
                children: [
                  VCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Lined([for (final n in items) _Row(n, onTap: () => _open(n))]),
                  ),
                  if (_more)
                    Padding(
                      padding: const EdgeInsets.only(top: Tp.s3),
                      child: OutlinedButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: Text(_loadingMore ? 'Loading…' : 'Show older'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.n, {required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  static final _when = DateFormat('d MMM yyyy, HH:mm', 'en_US');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final icon = switch (n.type) {
      'reminder' || 'payment' => LucideIcons.calendarClock,
      'success' => LucideIcons.circleCheck,
      'warning' || 'danger' => LucideIcons.triangleAlert,
      _ => LucideIcons.bell,
    };
    return Semantics(
      button: true,
      label: '${n.read ? '' : 'Unread. '}${n.title}. ${n.message}',
      child: InkWell(
        key: Key('notification-${n.id}'),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Tp.navySoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: Tp.navy2),
                ),
                const SizedBox(width: Tp.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title.isEmpty ? 'Tabital Pay' : n.title,
                        style: t.titleSmall?.copyWith(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(n.message, style: t.bodyMedium?.copyWith(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        [if (n.createdAt != null) _when.format(n.createdAt!.toLocal()), ?n.actionText].join(' · '),
                        style: t.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!n.read)
                  Container(
                    key: Key('unread-${n.id}'),
                    margin: const EdgeInsets.only(left: Tp.s2, top: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Tp.gold, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
