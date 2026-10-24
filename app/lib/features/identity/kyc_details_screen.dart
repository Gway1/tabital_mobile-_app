import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'identity_models.dart';

/// "Your details" in Verify identity (U4, 2026-10-25): what sign-up no longer asks for. Same groups
/// as the web's "Your Details" tab. Saves only what the customer filled in (partial saves are fine);
/// `PUT /customer/kyc/details` checks everything and answers `{error, field}`.
class KycDetailsScreen extends StatefulWidget {
  const KycDetailsScreen({super.key, this.today});
  final DateTime? today;

  @override
  State<KycDetailsScreen> createState() => _KycDetailsScreenState();
}

const _textFields = [
  'national_id',
  'city',
  'address',
  'gps',
  'designation',
  'company',
  'monthly_salary',
  'momo_number',
  'ref_name',
  'ref_phone',
  'ref_relationship',
];

class _KycDetailsScreenState extends State<KycDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {for (final k in _textFields) k: TextEditingController()};
  KycState? _state;
  String? _loadError;
  DateTime? _employedSince;
  bool? _salaryToBank;
  bool _saving = false;
  String? _error;
  final Map<String, String> _serverErrors = {};

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final s = await AppScope.of(context).customer.kycDetails();
      if (!mounted) return;
      for (final k in _textFields) {
        _c[k]!.text = s.details.text(k);
      }
      setState(() {
        _state = s;
        _employedSince = parseApiDate(s.details.values['employment_start_date']);
        _salaryToBank = s.details.flag('salary_paid_to_bank');
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = errorText(e, "Couldn't load your details."));
    }
  }

  String _v(String k) => _c[k]!.text.trim();

  /// Only what's filled in, in the server's format.
  Map<String, Object?> _filled() {
    final out = <String, Object?>{};
    for (final k in _textFields) {
      var v = _v(k);
      if (v.isEmpty) continue;
      if (k == 'national_id') v = normaliseGhanaCard(v);
      if (k == 'monthly_salary') v = v.replaceAll(',', '');
      if (k == 'momo_number' || k == 'ref_phone') v = v.replaceAll(' ', '');
      out[k] = v;
    }
    if (_employedSince != null) out['employment_start_date'] = apiDate(_employedSince!);
    if (_salaryToBank != null) out['salary_paid_to_bank'] = _salaryToBank;
    return out;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _serverErrors.clear();
      _error = null;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      setState(() => _error = 'Please check the highlighted fields.');
      return;
    }
    final fields = _filled();
    if (fields.isEmpty) {
      setState(() => _error = 'Fill in at least one detail to save.');
      return;
    }
    setState(() => _saving = true);
    try {
      final s = await AppScope.of(context).customer.saveKycDetails(fields);
      if (!mounted) return;
      setState(() => _state = s);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.message ?? 'Details saved.')));
      if (s.checklist.detailsMissing.isEmpty) context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final field = e.body is Map ? (e.body as Map)['field'] : null;
      setState(() {
        if (field is String) _serverErrors[field] = e.message;
        _error = e.message;
      });
      _form.currentState?.validate();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    TextInputType? keyboard,
    List<String>? autofill,
    String? Function(String?)? check,
    int lines = 1,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tp.s3),
      child: TextFormField(
        key: Key('kyc-$key'),
        controller: _c[key],
        keyboardType: keyboard,
        autofillHints: autofill,
        minLines: lines,
        maxLines: lines,
        textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
        onChanged: (_) {
          if (_serverErrors.remove(key) != null) setState(() {});
        },
        decoration: InputDecoration(labelText: optional ? '$label (optional)' : label, helperText: hint, helperMaxLines: 2),
        // Partial saves: an empty field is skipped, a filled one must be right
        validator: (v) {
          if (_serverErrors[key] != null) return _serverErrors[key];
          if ((v ?? '').trim().isEmpty) return null;
          return check?.call(v);
        },
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
    final s = _state;
    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
      body: _loadError != null
          ? ErrorPanel(message: _loadError!, onRetry: _load)
          : s == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: pagePadding,
                      children: [
                        if (s.checklist.detailsMissing.isNotEmpty)
                          Note(
                            'Still to add: ${s.checklist.detailsMissing.join(', ')}. You can save as you go.',
                            key: const Key('kyc-missing'),
                            icon: LucideIcons.listChecks,
                            tone: NoteTone.warn,
                          )
                        else
                          const Note('All your details are added. You can still correct them here.', tone: NoteTone.success),
                        _section(LucideIcons.idCard, 'Ghana Card'),
                        _field(
                          'national_id',
                          'Ghana Card number',
                          hint: 'e.g. GHA-123456789-0. Needed before the selfie check.',
                          check: ghanaCardError,
                        ),
                        _section(LucideIcons.mapPin, 'Where you live'),
                        _field('city', 'City or town', autofill: const [AutofillHints.addressCity]),
                        _field(
                          'address',
                          'Home address',
                          hint: 'House number, street and a landmark',
                          lines: 2,
                          autofill: const [AutofillHints.fullStreetAddress],
                        ),
                        _field('gps', 'Ghana Post GPS address', hint: 'e.g. GA-123-4567', optional: true),
                        _section(
                          LucideIcons.briefcase,
                          'Work and income',
                          'We use this to set your spending limit, and we check it against your salary details.',
                        ),
                        _field('designation', 'Job title', optional: true, autofill: const [AutofillHints.jobTitle]),
                        _field('company', 'Employer', optional: true, autofill: const [AutofillHints.organizationName]),
                        _field(
                          'monthly_salary',
                          'Monthly salary (GHS)',
                          hint: 'Your take-home pay each month',
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                          check: salaryError,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Tp.s3),
                          child: InkWell(
                            key: const Key('kyc-employment_start_date'),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _employedSince ?? _today,
                                firstDate: DateTime(1960),
                                lastDate: _today,
                                helpText: 'Start date',
                                initialEntryMode: DatePickerEntryMode.input,
                              );
                              if (d != null) {
                                setState(() {
                                  _employedSince = d;
                                  _serverErrors.remove('employment_start_date');
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Started with this employer',
                                errorText: _serverErrors['employment_start_date'],
                                suffixIcon: const Icon(LucideIcons.calendar),
                              ),
                              child: Text(_employedSince == null ? 'Choose a date' : formatDate(_employedSince)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Tp.s3),
                          child: DropdownButtonFormField<bool>(
                            key: const Key('kyc-salary_paid_to_bank'),
                            initialValue: _salaryToBank,
                            decoration: InputDecoration(
                              labelText: 'Is your salary paid into a bank account?',
                              errorText: _serverErrors['salary_paid_to_bank'],
                            ),
                            items: const [
                              DropdownMenuItem(value: true, child: Text('Yes')),
                              DropdownMenuItem(value: false, child: Text('No')),
                            ],
                            onChanged: (v) => setState(() => _salaryToBank = v),
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
                          "Someone who knows you, such as a relative or colleague. Let them know you've named them. We'll only "
                              "contact them if we can't reach you or to confirm who you are. We'll never tell them what you owe.",
                        ),
                        _field('ref_name', 'Their full name'),
                        _field('ref_phone', 'Their phone number', keyboard: TextInputType.phone, check: phoneError),
                        _field('ref_relationship', 'How you know them', hint: 'e.g. brother, colleague, friend'),
                        if (_error != null) ...[const SizedBox(height: Tp.s2), Notice(_error!, tone: NoticeTone.error)],
                      ],
                    ),
                  ),
                  PayBar(
                    button: FilledButton(
                      key: const Key('kyc-save'),
                      onPressed: _saving ? null : _save,
                      child: _saving ? const ButtonSpinner() : const Text('Save details'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
