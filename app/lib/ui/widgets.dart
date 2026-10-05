import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api_client.dart';
import 'tokens.dart';
import 'vault.dart';

/// A status as a word, an icon and a colour (never colour alone), like the web app's tp-chip.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static const _known = <String, (String, String)>{
    'paid': ('success', 'Paid'),
    'completed': ('success', 'Completed'),
    'active': ('info', 'Active'),
    'pending': ('warn', 'Pending'),
    'due': ('warn', 'Due'),
    'overdue': ('error', 'Overdue'),
    'defaulted': ('error', 'Defaulted'),
    'cancelled': ('neutral', 'Cancelled'),
  };

  @override
  Widget build(BuildContext context) {
    final known = _known[status];
    final tone = known?.$1 ?? 'neutral';
    final text = label ?? known?.$2 ?? _title(status);
    final (fg, bg, icon) = switch (tone) {
      'success' => (Tp.success, Tp.successBg, LucideIcons.circleCheck),
      'warn' => (Tp.warn, Tp.warnBg, LucideIcons.clock),
      'error' => (Tp.error, Tp.errorBg, LucideIcons.circleAlert),
      'info' => (Tp.info, Tp.infoBg, LucideIcons.info),
      _ => (Tp.muted, Tp.surface2, LucideIcons.circle),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tp.s2, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: Tp.s1),
          Text(
            text,
            style: TextStyle(color: fg, fontSize: Tp.textSm, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _title(String s) {
    final t = s.replaceAll('_', ' ');
    return t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);
  }
}

/// A short message with a retry, for a screen that couldn't load.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Tp.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.cloudOff, size: 32, color: Tp.muted),
          const SizedBox(height: Tp.s3),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: Tp.s4),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Icon, title and text for an empty list.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Tp.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Tp.muted),
          const SizedBox(height: Tp.s3),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (text != null) ...[const SizedBox(height: Tp.s2), Text(text!, textAlign: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: Tp.s4), action!],
        ],
      ),
    );
  }
}

/// The real Tabital mark (assets/brand), optionally with "Tabital Pay" set in Poppins beside
/// it, the same lockup as the web app's sign-in. [height] is the mark's height.
class TabitalMark extends StatelessWidget {
  const TabitalMark({super.key, this.height = 40, this.withName = false, this.nameColor = Tp.onNavy});
  final double height;
  final bool withName;
  final Color nameColor;

  static const asset = 'assets/brand/mark.png';

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(asset, height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    return Semantics(
      label: 'Tabital Pay',
      image: true,
      child: ExcludeSemantics(
        child: withName
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                mark,
                SizedBox(width: height * 0.3),
                Text('Tabital Pay',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(color: nameColor, fontSize: height * 0.55, fontWeight: FontWeight.w700)),
              ])
            : mark,
      ),
    );
  }
}

/// A message box: info, warning, error or success, always with an icon and words.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.tone = NoticeTone.info, this.title, this.action});
  final String text;
  final String? title;
  final NoticeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Note(
        text,
        title: title,
        action: action,
        icon: switch (tone) {
          NoticeTone.info => LucideIcons.info,
          NoticeTone.warn => LucideIcons.triangleAlert,
          NoticeTone.error => LucideIcons.circleAlert,
          NoticeTone.success => LucideIcons.circleCheck,
        },
        tone: switch (tone) {
          NoticeTone.info => NoteTone.info,
          NoticeTone.warn => NoteTone.warn,
          NoticeTone.error => NoteTone.error,
          NoticeTone.success => NoteTone.success,
        },
      );
}

enum NoticeTone { info, warn, error, success }

/// A label and an amount on one line, as in a summary card.
class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.value, {super.key, this.strong = false, this.valueKey, this.sub});
  final String label;
  final String value;
  final String? sub;
  final bool strong;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tp.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: strong ? t.bodyMedium?.copyWith(fontWeight: FontWeight.w700) : null),
                if (sub != null) Text(sub!, style: t.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Tp.s3),
          // Long values (e.g. "GHS 4,050.00 → GHS 4,130.00") wrap instead of overflowing a small phone
          Flexible(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.end,
              style: strong ? t.titleMedium : t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small spinner for inside a gold button (navy on gold).
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Tp.navy));
}

/// The message to show for a failed call.
String errorText(Object? error, String fallback) {
  if (error is ApiException) return error.message;
  return fallback;
}
