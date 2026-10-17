import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// S3: phone and password.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.initialPhone});

  /// Filled in after sign-up.
  final String? initialPhone;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) _phone.text = widget.initialPhone!;
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth.signIn(_phone.text, _password.text);
      // The router moves to Home when the auth state changes
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = AppScope.of(context).auth.notice;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Tp.s5),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: Tp.s6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabitalMark(height: 36, withName: true, nameColor: Tp.navy),
                ),
              ),
              if (notice != null) _Banner(text: notice, tone: Tp.info, bg: Tp.infoBg, icon: LucideIcons.info),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Phone number', hintText: '024 123 4567'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your phone number' : null,
              ),
              const SizedBox(height: Tp.s4),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _hide ? 'Show password' : 'Hide password',
                    icon: Icon(_hide ? LucideIcons.eye : LucideIcons.eyeOff),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: Tp.s4),
                _Banner(text: _error!, tone: Tp.error, bg: Tp.errorBg, icon: LucideIcons.circleAlert),
              ],
              const SizedBox(height: Tp.s6),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Tp.navy))
                    : const Text('Sign in'),
              ),
              const SizedBox(height: Tp.s4),
              TextButton(
                key: const Key('forgot-password'),
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Forgot your password?'),
              ),
              const SizedBox(height: Tp.s2),
              TextButton(onPressed: () => context.go('/sign-up'), child: const Text('New to Tabital? Create an account')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone, required this.bg, required this.icon});
  final String text;
  final Color tone;
  final Color bg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tp.s4),
      padding: const EdgeInsets.all(Tp.s3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Tp.radius)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: Tp.s2),
          Expanded(
            child: Text(text, style: TextStyle(color: tone)),
          ),
        ],
      ),
    );
  }
}
