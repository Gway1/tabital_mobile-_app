import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Ghana mobile numbers, the same check as the web sign-up.
final _ghanaMobile = RegExp(r'^(054|055|059|020|024|025|026|027|050|053|057|056)[0-9]{7}$');

String? phoneError(String? v, {bool required = true}) {
  final s = (v ?? '').trim().replaceAll(' ', '');
  if (s.isEmpty) return required ? 'Mobile number is required' : null;
  if (!_ghanaMobile.hasMatch(s) || RegExp(r'^(\d)\1{9}$').hasMatch(s)) {
    return 'Please enter a valid Ghana mobile number (e.g., 024XXXXXXX)';
  }
  return null;
}

String? passwordError(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Password is required';
  if (s.length < 10) return 'Password must be at least 10 characters';
  if (s.length > 128) return 'Password is too long (maximum 128 characters)';
  return null;
}

/// S2: create a customer account. The same fields as the web sign-up; the server checks them
/// all again, and Tabital verifies salary and employment before giving a limit.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.today});
  final DateTime? today;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in const [
      'full_name',
      'business_email',
      'phone',
      'national_id',
      'city',
      'gps',
      'address',
      'designation',
      'company',
      'monthly_salary',
      'momo_number',
      'ref_name',
      'ref_phone',
      'ref_relationship',
      'password',
      'confirm',
    ])
      k: TextEditingController(),
  };
  DateTime? _dob;
  DateTime? _employedSince;
  bool? _salaryToBank;
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
    if (!valid || _dob == null || _employedSince == null || _salaryToBank == null) {
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
      await AppScope.of(context).auth.register({
        'full_name': _v('full_name'),
        'business_email': _v('business_email'),
        'phone': phone,
        'dob': apiDate(_dob!),
        'national_id': _v('national_id').toUpperCase(),
        'city': _v('city'),
        'gps': _v('gps'),
        'address': _v('address'),
        'designation': _v('designation'),
        'company': _v('company'),
        'monthly_salary': _v('monthly_salary').replaceAll(',', ''),
        'employment_start_date': apiDate(_employedSince!),
        'salary_paid_to_bank': _salaryToBank,
        'momo_number': _v('momo_number').replaceAll(' ', ''),
        'ref_name': _v('ref_name'),
        'ref_phone': _v('ref_phone').replaceAll(' ', ''),
        'ref_relationship': _v('ref_relationship'),
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
        if (field is String && _c.containsKey(field)) _serverErrors[field] = e.message;
        if (field == 'employment_start_date') _serverErrors['employment_start_date'] = e.message;
        _error = e.message;
      });
      _form.currentState?.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onPick,
    required String help,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? last,
      firstDate: first,
      lastDate: last,
      helpText: help,
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (d != null) setState(() => onPick(d));
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool required = true,
    TextInputType? keyboard,
    List<String>? autofill,
    String? Function(String?)? check,
    int lines = 1,
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
        minLines: lines,
        maxLines: obscure ? 1 : lines,
        textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
        onChanged: (_) {
          if (_serverErrors.remove(key) != null) setState(() {});
        },
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          helperText: hint,
          helperMaxLines: 2,
          suffixIcon: suffix,
        ),
        validator: (v) {
          if (_serverErrors[key] != null) return _serverErrors[key];
          if (required && (v ?? '').trim().isEmpty) return 'Enter your ${label.toLowerCase()}';
          return check?.call(v);
        },
      ),
    );
  }

  Widget _dateField(String key, String label, DateTime? value, VoidCallback onTap, {String? hint}) {
    final error = _serverErrors[key] ?? (_error != null && value == null ? 'Choose a date' : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tp.s3),
      child: InkWell(
        key: Key('su-$key'),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '$label *',
            helperText: hint,
            errorText: error,
            suffixIcon: const Icon(LucideIcons.calendar),
          ),
          child: Text(value == null ? 'Choose a date' : formatDate(value)),
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title, [String? lead]) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Tp.s4, bottom: Tp.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Tp.navy2),
              const SizedBox(width: Tp.s2),
              Expanded(child: Text(title, style: t.titleMedium)),
            ],
          ),
          if (lead != null) ...[const SizedBox(height: Tp.s1), Text(lead, style: t.bodySmall)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adult = DateTime(_today.year - 18, _today.month, _today.day);
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Tp.s4),
            children: [
              const Text('Fields marked * are required.'),
              _section(LucideIcons.user, 'About you'),
              _field('full_name', 'Full name', hint: 'As it appears on your Ghana Card', autofill: const [AutofillHints.name]),
              _dateField(
                'dob',
                'Date of birth',
                _dob,
                hint: 'You must be 18 or older',
                () =>
                    _pickDate(current: _dob, first: DateTime(1920), last: adult, onPick: (d) => _dob = d, help: 'Date of birth'),
              ),
              _field(
                'business_email',
                'Email',
                keyboard: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
                check: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Please enter a valid email address',
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
                'national_id',
                'Ghana Card number',
                hint: 'e.g. GHA-123456789-0. We verify it with a selfie later.',
                // The server's rule: GHA, 9 digits, 1 digit, with any spaces or dashes
                check: (v) => RegExp(r'^GHA\d{10}$').hasMatch((v ?? '').toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), ''))
                    ? null
                    : 'Enter the Ghana Card number as GHA-XXXXXXXXX-X',
              ),
              _section(LucideIcons.mapPin, 'Where you live'),
              _field('city', 'City or town', autofill: const [AutofillHints.addressCity]),
              _field('gps', 'Ghana Post GPS address', hint: 'e.g. GA-123-4567', required: false),
              _field(
                'address',
                'Home address',
                hint: 'House number, street and a landmark',
                lines: 2,
                autofill: const [AutofillHints.fullStreetAddress],
              ),
              _section(
                LucideIcons.briefcase,
                'Work and income',
                'We use this to set your spending limit, and we check it against your salary details before you buy.',
              ),
              _field('designation', 'Job title', required: false, autofill: const [AutofillHints.jobTitle]),
              _field('company', 'Employer', required: false, autofill: const [AutofillHints.organizationName]),
              _field(
                'monthly_salary',
                'Monthly salary (GHS)',
                hint: 'Your take-home pay each month',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                check: (v) {
                  final p = parseAmountInput(v ?? '');
                  return p == null || p <= 0 ? 'Enter your monthly salary, e.g. 5000' : null;
                },
              ),
              _dateField(
                'employment_start_date',
                'Started with this employer',
                _employedSince,
                () => _pickDate(
                  current: _employedSince,
                  first: DateTime(1960),
                  last: _today,
                  onPick: (d) => _employedSince = d,
                  help: 'Start date',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Tp.s3),
                child: DropdownButtonFormField<bool>(
                  key: const Key('su-salary_paid_to_bank'),
                  initialValue: _salaryToBank,
                  decoration: const InputDecoration(labelText: 'Is your salary paid into a bank account? *'),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Yes')),
                    DropdownMenuItem(value: false, child: Text('No')),
                  ],
                  onChanged: (v) => setState(() => _salaryToBank = v),
                  validator: (v) => v == null ? 'Choose Yes or No' : null,
                ),
              ),
              _field(
                'momo_number',
                'Mobile Money number',
                hint: 'The MoMo number in your name',
                keyboard: TextInputType.phone,
                check: phoneError,
              ),
              _section(
                LucideIcons.users,
                'A person we can contact',
                "Someone who knows you, such as a relative or colleague. Let them know you've named them. We'll only contact "
                    "them if we can't reach you or to confirm who you are. We'll never tell them what you owe.",
              ),
              _field('ref_name', 'Their full name'),
              _field('ref_phone', 'Their phone number', keyboard: TextInputType.phone, check: phoneError),
              _field('ref_relationship', 'How you know them', hint: 'e.g. brother, colleague, friend'),
              _section(LucideIcons.lock, 'Your password'),
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
              CheckboxListTile(
                key: const Key('su-agree'),
                value: _agree,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _agree = v ?? false),
                title: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(text: 'Terms and Conditions', style: _link, recognizer: _termsTap),
                      const TextSpan(text: ' and the '),
                      TextSpan(text: 'Privacy Policy', style: _link, recognizer: _privacyTap),
                    ],
                  ),
                ),
              ),
              CheckboxListTile(
                value: _marketing,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _marketing = v ?? false),
                title: const Text('Send me offers and news from Tabital Pay (optional). Payment reminders come either way.'),
              ),
              if (_error != null) ...[const SizedBox(height: Tp.s2), Notice(_error!, tone: NoticeTone.error)],
              const SizedBox(height: Tp.s4),
              FilledButton(
                key: const Key('su-submit'),
                onPressed: _busy || !_agree ? null : _submit,
                child: _busy ? const ButtonSpinner() : const Text('Create account'),
              ),
              const SizedBox(height: Tp.s3),
              TextButton(onPressed: () => context.go('/sign-in'), child: const Text('Already have an account? Sign in')),
            ],
          ),
        ),
      ),
    );
  }

  static const _link = TextStyle(color: Tp.navy2, decoration: TextDecoration.underline, fontWeight: FontWeight.w600);
}
