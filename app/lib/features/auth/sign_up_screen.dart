import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/validators.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';

export '../../core/validators.dart' show phoneError, passwordError;

/// S2: create a customer account. The short web sign-up (U2, 2026-10-25): name, date of birth,
/// email, phone and password. Address, work and income, the Ghana Card, MoMo and a reference are
/// given later, in Verify identity (`/account/identity`).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.today});
  final DateTime? today;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in const ['full_name', 'business_email', 'phone', 'password', 'confirm']) k: TextEditingController(),
  };
  DateTime? _dob;
  bool _agree = false;
  bool _marketing = false;
  bool _hide = true;
  bool _busy = false;
  String? _error;
  final Map<String, String> _serverErrors = {};
  late final _termsTap = TapGestureRecognizer()..onTap = () => openLink(AppConfig.termsUrl);
  late final _privacyTap = TapGestureRecognizer()..onTap = () => openLink(AppConfig.privacyUrl);

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  String _v(String k) => _c[k]!.text.trim();

  Future<void> _submit() async {
    setState(() {
      _serverErrors.clear();
      _error = null;
    });
    final valid = _form.currentState?.validate() ?? false;
    if (!valid || _dob == null) {
      setState(() => _error = 'Please check the highlighted fields.');
      return;
    }
    if (!_agree) {
      setState(() => _error = 'You need to agree to the Terms and the Privacy Policy to continue.');
      return;
    }
    setState(() => _busy = true);
    final phone = _v('phone').replaceAll(' ', '');
    try {
      // Only these: everything else is given at verification (U2)
      await AppScope.of(context).auth.register({
        'full_name': _v('full_name'),
        'business_email': _v('business_email'),
        'phone': phone,
        'dob': apiDate(_dob!),
        'agree': true,
        'marketing_consent': _marketing,
        'password': _c['password']!.text,
      });
      if (!mounted) return;
      context.go('/sign-in', extra: phone);
    } on ApiException catch (e) {
      if (!mounted) return;
      final field = e.body is Map ? (e.body as Map)['field'] : null;
      setState(() {
        if (field is String && (_c.containsKey(field) || field == 'dob')) _serverErrors[field] = e.message;
        _error = e.message; // the server's own reason (U8)
      });
      _form.currentState?.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDob(DateTime adult) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? adult,
      firstDate: DateTime(1920),
      lastDate: adult,
      helpText: 'Date of birth',
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (d != null) {
      setState(() {
        _dob = d;
        _serverErrors.remove('dob');
      });
    }
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    TextInputType? keyboard,
    List<String>? autofill,
    String? Function(String?)? check,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tp.s3),
      child: TextFormField(
        key: Key('su-$key'),
        controller: _c[key],
        keyboardType: keyboard,
        autofillHints: autofill,
        obscureText: obscure,
        textInputAction: TextInputAction.next,
        onChanged: (_) {
          if (_serverErrors.remove(key) != null) setState(() {});
        },
        decoration: InputDecoration(labelText: '$label *', helperText: hint, helperMaxLines: 2, suffixIcon: suffix),
        validator: (v) {
          if (_serverErrors[key] != null) return _serverErrors[key];
          if ((v ?? '').trim().isEmpty) return 'Enter your ${label.toLowerCase()}';
          return check?.call(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final adult = DateTime(_today.year - 18, _today.month, _today.day);
    final dobError = _serverErrors['dob'] ?? (_error != null && _dob == null ? 'Choose a date' : null);
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Tp.s4),
            children: [
              const Text('Fields marked * are required.'),
              const SizedBox(height: Tp.s4),
              _field('full_name', 'Full name', hint: 'As it appears on your Ghana Card', autofill: const [AutofillHints.name]),
              Padding(
                padding: const EdgeInsets.only(bottom: Tp.s3),
                child: InkWell(
                  key: const Key('su-dob'),
                  onTap: () => _pickDob(adult),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of birth *',
                      helperText: 'You must be 18 or older',
                      errorText: dobError,
                      suffixIcon: const Icon(LucideIcons.calendar),
                    ),
                    child: Text(_dob == null ? 'Choose a date' : formatDate(_dob)),
                  ),
                ),
              ),
              _field(
                'business_email',
                'Email',
                keyboard: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
                check: emailError,
              ),
              _field(
                'phone',
                'Phone number',
                hint: "You'll sign in with this number, e.g. 0241234567",
                keyboard: TextInputType.phone,
                autofill: const [AutofillHints.telephoneNumber],
                check: phoneError,
              ),
              _field(
                'password',
                'Password',
                hint: 'At least 10 characters',
                obscure: _hide,
                autofill: const [AutofillHints.newPassword],
                check: passwordError,
                suffix: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(_hide ? LucideIcons.eye : LucideIcons.eyeOff),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              _field(
                'confirm',
                'Confirm password',
                obscure: _hide,
                check: (v) => v == _c['password']!.text ? null : "The passwords don't match",
              ),
              CheckRow(
                boxKey: const Key('su-agree'),
                value: _agree,
                onChanged: (v) => setState(() => _agree = v),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(text: 'Terms and Conditions', style: linkStyle, recognizer: _termsTap),
                      const TextSpan(text: ' and the '),
                      TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: _privacyTap),
                    ],
                  ),
                ),
              ),
              CheckRow(
                value: _marketing,
                onChanged: (v) => setState(() => _marketing = v),
                child: const Text('Send me offers and news from Tabital Pay (optional). Payment reminders come either way.'),
              ),
              const SizedBox(height: Tp.s3),
              Note(
                "That's all for now. After you sign up, you'll add your address, work and income, Ghana Card and a person "
                'we can contact when you verify your identity.',
                key: const Key('su-next'),
                icon: LucideIcons.listChecks,
              ),
              if (_error != null) ...[const SizedBox(height: Tp.s3), Notice(_error!, tone: NoticeTone.error)],
              const SizedBox(height: Tp.s4),
              FilledButton(
                key: const Key('su-submit'),
                onPressed: _busy || !_agree ? null : _submit,
                child: _busy ? const ButtonSpinner() : const Text('Create account'),
              ),
              const SizedBox(height: Tp.s3),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: Text('Already have an account? Sign in', style: t.labelLarge?.copyWith(color: Tp.navy2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
