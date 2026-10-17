import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'support_models.dart';

/// Report a problem with a purchase (G5, buyer protection). Same reasons, rules and wording as the
/// web instalments screen. The server pauses the plan's remaining payments while it's reviewed.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, required this.planId});
  final int planId;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _reason = disputeReasons.first.$1;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await AppScope.of(context).customer
          .reportProblem(planId: widget.planId, reason: _reason, description: _description.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, 'Could not send your report. Please try again.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: Form(
        key: _form,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: pagePadding,
                children: [
                  const Note(
                    "We'll pause your remaining payments while we look into it. Contact the shop first if you can.",
                    icon: LucideIcons.shieldCheck,
                  ),
                  const SectionTitle("What's wrong?"),
                  VCard(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: RadioGroup<String>(
                      groupValue: _reason,
                      onChanged: (v) => setState(() => _reason = v ?? _reason),
                      child: Column(
                        children: [
                          for (final (value, label) in disputeReasons)
                            RadioListTile<String>(
                              key: Key('reason-$value'),
                              value: value,
                              title: Text(label, style: t.bodyMedium),
                              activeColor: Tp.navy,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SectionTitle('What happened?'),
                  TextFormField(
                    key: const Key('problem-description'),
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(hintText: 'Tell us what happened (at least 10 characters)'),
                    validator: (v) =>
                        (v ?? '').trim().length < 10 ? 'Please describe the problem (at least 10 characters)' : null,
                  ),
                  if (_error != null) ...[const SizedBox(height: Tp.s3), Notice(_error!, tone: NoticeTone.error)],
                ],
              ),
            ),
            PayBar(
              button: FilledButton.icon(
                key: const Key('send-report'),
                onPressed: _sending ? null : _send,
                icon: _sending ? const ButtonSpinner() : const Icon(LucideIcons.send, size: 18),
                label: Text(_sending ? 'Sending…' : 'Send report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
