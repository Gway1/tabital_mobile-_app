import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/config.dart';
import '../../core/links.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'identity_models.dart';
import 'smile_capture.dart';

enum _Step { loading, intro, uploading, waiting, done, error }

/// S13: Ghana Card + selfie with liveness, checked by Smile ID (§9A). The images go from the
/// phone straight to Smile ID with a short-lived token from the API; Tabital never stores them.
class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key, this.pollEvery = const Duration(seconds: 10)});
  final Duration pollEvery;

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  _Step _step = _Step.loading;
  IdentityStatus? _status;
  bool _consent = false;
  bool _starting = false;
  String? _error;
  Timer? _poll;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()..onTap = () => openLink(AppConfig.privacyUrl);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await AppScope.of(context).customer.identity();
      if (!mounted) return;
      setState(() => _status = s);
      if (s.verified) {
        setState(() => _step = _Step.done);
      } else if (s.inProgress) {
        _startPolling();
      } else {
        setState(() => _step = _Step.intro);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.error;
          _error = errorText(e, 'Could not load your verification status.');
        });
      }
    }
  }

  Future<void> _begin() async {
    if (!_consent || _starting) return;
    final scope = AppScope.of(context);
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final session = await scope.customer.startIdentityCheck();
      if (!mounted) return;
      final capture = await scope.camera.capture(context);
      if (!mounted || capture == null) return; // closed the camera
      setState(() => _step = _Step.uploading);
      final jobId = await (scope.smile ?? SmileUploader()).upload(session, capture);
      try {
        await scope.customer.identitySubmitted(session.checkId, jobId);
      } catch (_) {
        // Smile ID has the job and tells the API itself; keep waiting either way
      }
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.intro;
          _error = errorText(e, 'Could not start the check. Please try again.');
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startPolling() {
    setState(() => _step = _Step.waiting);
    _poll?.cancel();
    var tries = 0;
    _poll = Timer.periodic(widget.pollEvery, (timer) async {
      tries++;
      if (tries > 60) timer.cancel(); // about 10 minutes; reopening the screen checks again
      try {
        final s = await AppScope.of(context).customer.identity();
        if (!mounted) return;
        setState(() => _status = s);
        if (s.verified) {
          timer.cancel();
          AppScope.of(context).customer.changed();
          setState(() => _step = _Step.done);
        } else if (s.checkStatus == 'blocked' || s.checkStatus == 'error') {
          timer.cancel();
          setState(() => _step = _Step.intro);
        } else if (s.checkStatus == 'review') {
          timer.cancel();
        }
      } catch (_) {
        // Try again on the next tick
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your identity')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final t = Theme.of(context).textTheme;
    switch (_step) {
      case _Step.loading:
        return const Center(child: CircularProgressIndicator());
      case _Step.error:
        return ErrorPanel(
          message: _error ?? 'Could not load your verification status.',
          onRetry: () {
            setState(() => _step = _Step.loading);
            _load();
          },
        );
      case _Step.uploading:
        return const _Centered(spinner: true, text: 'Sending securely to Smile ID…');
      case _Step.waiting:
        return _status?.checkStatus == 'review'
            ? const _Centered(
                icon: LucideIcons.userSearch,
                text: "Our team is reviewing your check. We'll let you know within one working day.",
              )
            : const _Centered(
                spinner: true,
                text: "Checking your identity. This usually takes a few minutes. You can leave this screen; we'll update your account.",
              );
      case _Step.done:
        return _Centered(
          icon: LucideIcons.badgeCheck,
          tone: Tp.success,
          title: "You're verified",
          text: 'Your identity is confirmed. You can now shop and pay in instalments.',
          action: FilledButton(onPressed: () => context.go('/shop'), child: const Text('Go to the shop')),
        );
      case _Step.intro:
        break;
    }

    final s = _status!;
    if (!s.configured) {
      return ListView(
        padding: pagePadding,
        children: const [
          Notice(
            "Selfie verification isn't switched on yet. Upload your Ghana Card under Documents on tabitalpay.com "
            'and our team will review it.',
            tone: NoticeTone.info,
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: pagePadding,
            children: [
              if (s.checkStatus == 'blocked') ...[
                Notice("We couldn't verify your identity. ${s.checkReasons.firstOrNull ?? ''}".trim(), tone: NoticeTone.error),
                const SizedBox(height: Tp.s3),
              ] else if (s.checkStatus == 'error') ...[
                const Notice("The last check didn't finish. Please try again.", tone: NoticeTone.warn),
                const SizedBox(height: Tp.s3),
              ],
              const SizedBox(height: Tp.s4),
              const Center(child: BigIcon(LucideIcons.scanFace)),
              const SizedBox(height: 18),
              Text(
                "We need to check it's really you before you can use a payment plan. It takes about 2 minutes.",
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: Tp.s4),
              const VCard(
                child: StepsList([
                  (LucideIcons.idCard, 'Your Ghana Card number', IconTone.navy),
                  (LucideIcons.camera, 'A selfie, with a quick liveness check', IconTone.navy),
                  (LucideIcons.badgeCheck, 'Usually confirmed in minutes', IconTone.navy),
                ]),
              ),
              const SizedBox(height: 12),
              const Note(
                'Smile ID checks your card and selfie for Tabital. Your photos stay with Smile ID. Tabital keeps the result. '
                'Have good light, take off glasses or a hat, and make sure your name and date of birth match your Ghana Card.',
                icon: LucideIcons.lock,
              ),
              const SizedBox(height: 14),
              CheckRow(
                boxKey: const Key('identity-consent'),
                value: _consent,
                onChanged: (v) => setState(() => _consent = v),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text:
                            'I agree that Smile ID can check my Ghana Card with the National Identification Authority and '
                            'compare my selfie with my ID photo for Tabital, as set out in the ',
                      ),
                      TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: _privacyTap),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[const SizedBox(height: Tp.s3), Notice(_error!, tone: NoticeTone.error)],
              const SizedBox(height: 10),
              Text(
                s.attemptsLeft == 0
                    ? 'You have no attempts left. Please contact info@tabitalpay.com.'
                    : 'You have ${s.attemptsLeft} attempt${s.attemptsLeft == 1 ? '' : 's'}.',
                key: const Key('identity-attempts'),
                style: t.bodySmall,
              ),
              const SizedBox(height: 6),
              Text('Details wrong? Update them in your profile on tabitalpay.com first.', style: t.bodySmall),
            ],
          ),
        ),
        PayBar(
          button: FilledButton.icon(
            key: const Key('identity-start'),
            onPressed: _consent && s.attemptsLeft > 0 && !_starting ? _begin : null,
            icon: _starting ? const ButtonSpinner() : const Icon(LucideIcons.scanFace, size: 18),
            label: const Text('Start verification'),
          ),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.icon, this.tone = Tp.navy2, this.title, this.spinner = false, this.action});
  final String text;
  final IconData? icon;
  final Color tone;
  final String? title;
  final bool spinner;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tp.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) const SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
            if (icon != null) BigIcon(icon!, tone: tone == Tp.success ? IconTone.ok : IconTone.navy),
            const SizedBox(height: Tp.s4),
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: Tp.s2),
            ],
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: Tp.s6), action!],
          ],
        ),
      ),
    );
  }
}
