import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tokens.dart';

/// Building blocks that match `design/prototype.html` class by class. Screens use these so the
/// app looks like the approved prototype.

/// `.money`: Poppins, navy, never wraps.
TextStyle moneyStyle(BuildContext context, [double size = 14, Color color = Tp.navy]) =>
    Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: size, color: color);

/// `.pad`: the page's side padding.
const pagePadding = EdgeInsets.fromLTRB(Tp.s4, 0, Tp.s4, Tp.s4);

/// `.card`: white, a thin line, radius 14, padding 14.
class VCard extends StatelessWidget {
  const VCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = Tp.surface, this.border = true});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Tp.radiusLg),
          border: border ? Border.all(color: Tp.line) : null,
        ),
        child: child,
      );
}

/// `h3`: a section heading, 18 above and 10 below.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// `.row`: a label on the left and a value (usually money) on the right.
class VRow extends StatelessWidget {
  const VRow(this.label, this.value, {super.key, this.valueKey, this.valueColor = Tp.navy, this.size = 14, this.labelStyle});
  final String label;
  final String value;
  final Key? valueKey;
  final Color valueColor;
  final double size;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: labelStyle ?? Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: size))),
          const SizedBox(width: Tp.s3),
          Flexible(
            child: Text(value, key: valueKey, textAlign: TextAlign.end, style: moneyStyle(context, size, valueColor)),
          ),
        ]),
      );
}

/// `.total`: a bold row under a 2 px navy line.
class TotalRow extends StatelessWidget {
  const TotalRow(this.label, this.value, {super.key, this.valueKey});
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: Tp.navy);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tp.navy, width: 2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: Tp.s3),
        Flexible(child: Text(value, key: valueKey, textAlign: TextAlign.end, style: style)),
      ]),
    );
  }
}

enum SchedState { normal, now, paid }

/// `.sched li`: a numbered circle (gold for "today", green tick when paid), what it is, the amount.
class SchedRow extends StatelessWidget {
  const SchedRow({super.key, required this.number, required this.title, this.sub, this.subWidget, required this.amount, this.state = SchedState.normal, this.trailing});
  final int number;
  final String title;
  final String? sub;
  final Widget? subWidget;
  final String amount;
  final SchedState state;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (bg, fg) = switch (state) {
      SchedState.now => (Tp.gold, Tp.navy),
      SchedState.paid => (Tp.successBg, Tp.success),
      SchedState.normal => (Tp.surface2, Tp.navy),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: state == SchedState.paid
              ? Icon(LucideIcons.check, size: 14, color: fg)
              : Text('$number', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        const SizedBox(width: Tp.s3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.bodyMedium),
            if (sub != null) Text(sub!, style: t.bodySmall?.copyWith(fontSize: 12)),
            ?subWidget,
          ]),
        ),
        const SizedBox(width: Tp.s2),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amount, style: moneyStyle(context)),
          ?trailing,
        ]),
      ]),
    );
  }
}

/// Rows separated by thin lines, as in `.sched` and `.list-row`.
class Lined extends StatelessWidget {
  const Lined(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(), c],
      ]);
}

/// `.paybar`: sticky at the bottom. An amount and a caption on the left, the gold button on the right.
class PayBar extends StatelessWidget {
  const PayBar({super.key, required this.button, this.amount, this.caption, this.amountKey, this.below});
  final Widget button;
  final String? amount;
  final String? caption;
  final Key? amountKey;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Tp.surface, border: Border(top: BorderSide(color: Tp.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tp.s4, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (amount != null) ...[
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(amount!, key: amountKey, style: moneyStyle(context, 15)),
                  if (caption != null) Text(caption!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
                ]),
                const SizedBox(width: Tp.s3),
              ],
              Expanded(child: button),
            ]),
            ?below,
          ]),
        ),
      ),
    );
  }
}

enum NoteTone { info, warn, error, success }

/// `.note`: an icon and text on a soft background.
class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.icon = LucideIcons.info, this.tone = NoteTone.info, this.title, this.action});
  final String text;
  final IconData icon;
  final NoteTone tone;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      NoteTone.info => (Tp.navy2, Tp.navySoft),
      NoteTone.warn => (Tp.warn, Tp.warnBg),
      NoteTone.error => (Tp.error, Tp.errorBg),
      NoteTone.success => (Tp.success, Tp.successBg),
    };
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, color: fg);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: fg)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: style?.copyWith(fontWeight: FontWeight.w700)),
            Text(text, style: style),
            if (action != null) ...[const SizedBox(height: Tp.s2), action!],
          ]),
        ),
      ]),
    );
  }
}

/// `.check`: a checkbox with a sentence (which may hold links). Tapping the box toggles it.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.value, required this.onChanged, required this.child, this.boxKey});
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final Key? boxKey;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Checkbox(key: boxKey, value: value, onChanged: (v) => onChanged(v ?? false)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13, height: 1.45), child: child),
          ),
        ),
      ]);
}

enum IconTone { ok, navy, error, warn }

/// `.big-ico`: a large icon in a soft circle, for results and intros.
class BigIcon extends StatelessWidget {
  const BigIcon(this.icon, {super.key, this.tone = IconTone.navy});
  final IconData icon;
  final IconTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      IconTone.ok => (Tp.success, Tp.successBg),
      IconTone.navy => (Tp.navy2, Tp.navySoft),
      IconTone.error => (Tp.error, Tp.errorBg),
      IconTone.warn => (Tp.warn, Tp.warnBg),
    };
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 42, color: fg),
    );
  }
}

/// `.steps`: icon tiles with a line of text each.
class StepsList extends StatelessWidget {
  const StepsList(this.steps, {super.key});
  final List<(IconData, String, IconTone)> steps;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (i, (icon, text, tone)) in steps.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone == IconTone.ok ? Tp.successBg : (tone == IconTone.error ? Tp.errorBg : Tp.navySoft),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: tone == IconTone.ok ? Tp.success : (tone == IconTone.error ? Tp.error : Tp.navy2)),
              ),
              const SizedBox(width: Tp.s3),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
            ]),
          ),
      ]);
}

/// `.seg`: three choices in a grey track; the chosen one is white.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Tp.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: Semantics(
              selected: v == value,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: v == value ? Tp.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: v == value ? const [BoxShadow(color: Color(0x1F02163F), blurRadius: 3, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(label,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: v == value ? Tp.navy : Tp.muted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// `.chip`: a small pill with an icon and a word.
class VChip extends StatelessWidget {
  const VChip(this.text, {super.key, this.icon, this.tone = NoteTone.info});
  final String text;
  final IconData? icon;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      NoteTone.info => (Tp.navy2, Tp.navySoft),
      NoteTone.warn => (Tp.warn, Tp.warnBg),
      NoteTone.error => (Tp.error, Tp.errorBg),
      NoteTone.success => (Tp.success, Tp.successBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// `.list-row`: an icon, a label and a chevron, for menus.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.icon, required this.label, this.trailing, this.onTap, this.color = Tp.navy});
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Icon(icon, size: 20, color: color == Tp.navy ? Tp.navy2 : color),
            const SizedBox(width: Tp.s3),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
            trailing ?? (onTap == null ? const SizedBox.shrink() : const Icon(LucideIcons.chevronRight, size: 18, color: Tp.muted)),
          ]),
        ),
      );
}

/// A link inside a sentence.
const linkStyle = TextStyle(color: Tp.navy2, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
