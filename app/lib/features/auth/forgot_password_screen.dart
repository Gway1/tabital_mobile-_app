import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'sign_up_screen.dart' show passwordError;

enum _Step { email, code, password }

/// Forgot password (G6): the web app's three steps. Email → the 6-digit code sent to it → a new
/// password. The server answers the same whether or not the email is registered.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.resendAfter = const Duration(seconds: 60)});
  final Duration resendAfter;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Step _step = _Step.email;
  String? _resetToken;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = widget.resendAfter.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, "That didn't work. Please try again."));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode({bool resend = false}) => _run(() async {
    await AppScope.of(context).auth.requestResetCode(_email.text);
    if (!mounted) return;
    setState(() {
      _step = _Step.code;
      if (resend) _info = 'We sent a new code. Check your email.';
    });
    _startTimer();
  });

  Future<void> _verify() => _run(() async {
    final token = await AppScope.of(context).auth.verifyResetCode(_email.text, _code.text);
    if (!mounted) return;
    setState(() {
      _resetToken = token;
      _step = _Step.password;
    });
  });

  Future<void> _reset() => _run(() async {
    await AppScope.of(context).auth.resetPassword(_resetToken!, _password.text);
    if (!mounted) return;
    context.go('/sign-in');
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (title, lead) = switch (_step) {
      _Step.email => ('Forgot your password?', 'Enter the email address on your account and we\'ll send you a reset code.'),
      _Step.code => ('Enter your code', 'Enter the 6-digit code sent to ${_email.text.trim()}. It works for 10 minutes.'),
      _Step.password => ('Create a new password', 'Use at least 10 characters.'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Reset your password')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Tp.s5),
            children: [
              const Center(child: BigIcon(LucideIcons.keyRound)),
              const SizedBox(height: Tp.s4),
              Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: Tp.s2),
              Text(lead, style: t.bodyMedium, textAlign: TextAlign.center, key: const Key('fp-lead')),
              const SizedBox(height: Tp.s6),
              if (_step == _Step.email)
                TextFormField(
                  key: const Key('fp-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendCode(),
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (v) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email address',
                ),
              if (_step == _Step.code) ...[
                TextFormField(
                  key: const Key('fp-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: moneyStyle(context, 24).copyWith(letterSpacing: 8),
                  decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 6 digits from the email',
                ),
                const SizedBox(height: Tp.s2),
                Center(
                  child: _wait > 0
                      ? Text('You can ask for a new code in $_wait s', style: t.bodySmall, key: const Key('fp-wait'))
                      : TextButton(onPressed: _busy ? null : () => _sendCode(resend: true), child: const Text('Send a new code')),
                ),
              ],
              if (_step == _Step.password) ...[
                TextFormField(
                  key: const Key('fp-password'),
                  controller: _password,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      tooltip: _hide ? 'Show password' : 'Hide password',
                      icon: Icon(_hide ? LucideIcons.eye : LucideIcons.eyeOff),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: passwordError,
                ),
                const SizedBox(height: Tp.s3),
                TextFormField(
                  key: const Key('fp-confirm'),
                  controller: _confirm,
                  obscureText: _hide,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  validator: (v) => v == _password.text ? null : "The passwords don't match",
                ),
              ],
              if (_info != null) ...[const SizedBox(height: Tp.s3), Notice(_info!, tone: NoticeTone.success)],
              if (_error != null) ...[const SizedBox(height: Tp.s3), Notice(_error!, tone: NoticeTone.error)],
              const SizedBox(height: Tp.s6),
              FilledButton(
                key: const Key('fp-submit'),
                onPressed: _busy
                    ? null
                    : switch (_step) {
                        _Step.email => () => _sendCode(),
                        _Step.code => _verify,
                        _Step.password => _reset,
                      },
                child: _busy
                    ? const ButtonSpinner()
                    : Text(switch (_step) {
                        _Step.email => 'Send reset code',
                        _Step.code => 'Check the code',
                        _Step.password => 'Save new password',
                      }),
              ),
              const SizedBox(height: Tp.s3),
              TextButton(onPressed: () => context.go('/sign-in'), child: const Text('Remember your password? Sign in')),
            ],
          ),
        ),
      ),
    );
  }
}
