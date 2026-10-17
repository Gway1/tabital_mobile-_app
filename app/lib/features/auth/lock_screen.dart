import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_lock.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Covers the app while it's locked (G9). Opens the phone's prompt at once; the customer can try
/// again, or sign in with their password instead.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.lock, required this.onSignInAgain});
  final AppLock lock;
  final VoidCallback onSignInAgain;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await widget.lock.unlock();
    if (mounted && !ok) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        key: const Key('lock-screen'),
        color: Tp.navy,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tp.s6),
            child: Column(
              children: [
                const Spacer(),
                const TabitalMark(height: 44),
                const SizedBox(height: Tp.s6),
                Text(
                  'Tabital Pay is locked',
                  style: t.headlineSmall?.copyWith(color: Tp.onNavy),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Tp.s2),
                Text(
                  _failed
                      ? "That didn't unlock the app. Try again, or sign in with your password."
                      : 'Use your fingerprint, face or phone PIN to carry on.',
                  key: const Key('lock-text'),
                  style: t.bodyMedium?.copyWith(color: Tp.onNavyMuted),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: widget.lock,
                  builder: (context, _) => SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('unlock'),
                      onPressed: widget.lock.unlocking ? null : _unlock,
                      icon: widget.lock.unlocking ? const ButtonSpinner() : const Icon(LucideIcons.fingerprint, size: 20),
                      label: const Text('Unlock'),
                    ),
                  ),
                ),
                const SizedBox(height: Tp.s2),
                TextButton(
                  key: const Key('lock-sign-in'),
                  style: TextButton.styleFrom(foregroundColor: Tp.onNavyMuted),
                  onPressed: widget.onSignInAgain,
                  child: const Text('Sign in with your password instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
