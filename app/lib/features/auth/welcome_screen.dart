import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// S1: the tagline, what Tabital does, then Create account and Sign in (prototype S1).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _whoCanApply(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Tp.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tp.s6, 0, Tp.s6, Tp.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who can apply?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Tp.s3),
              for (final line in const [
                '18 or older, with a Ghana Card',
                'Employed for 6 months or more',
                'A regular salary paid into a bank account', // the minimum income is a setting, so it isn't written here
                'A Mobile Money number in your name',
                'A good record of paying back',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Tp.s2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(LucideIcons.check, size: 16, color: Tp.success),
                      ),
                      const SizedBox(width: Tp.s2),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Tp.navy,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Tp.s6, 28, Tp.s6, Tp.s6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 28 - Tp.s6),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TabitalMark(height: 40, withName: true),
                      const SizedBox(height: 34),
                      Text('Own It Today.\nPay Later.', style: t.headlineMedium?.copyWith(color: Tp.onNavy, height: 1.2)),
                      const SizedBox(height: 10),
                      Text(
                        'Buy phones, laptops and appliances from partner shops. Pay a down payment today and the rest '
                        'in monthly payments, interest-free when you pay on time.',
                        style: t.bodyLarge?.copyWith(color: Tp.onNavyMuted, height: 1.55),
                      ),
                      const SizedBox(height: 26),
                      for (final (icon, text) in const [
                        (LucideIcons.calendarCheck, 'Pay in 2, 3 or 4 with a clear schedule'),
                        (LucideIcons.shieldCheck, 'Every fee shown before you agree'),
                        (LucideIcons.smartphone, 'Pay by MoMo or card through Paystack'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Icon(icon, size: 20, color: Tp.gold),
                              const SizedBox(width: Tp.s3),
                              Expanded(
                                child: Text(text, style: t.bodyMedium?.copyWith(color: Tp.onNavy)),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      const SizedBox(height: Tp.s6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: () => context.push('/sign-up'), child: const Text('Create account')),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Tp.onNavy,
                            side: const BorderSide(color: Color(0x59FFFFFF), width: 1.5),
                          ),
                          onPressed: () => context.push('/sign-in'),
                          child: const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Tp.onNavyMuted, minimumSize: const Size(48, 36)),
                          onPressed: () => _whoCanApply(context),
                          child: const Text('Who can apply?', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
