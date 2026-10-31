import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import '../../ui/widgets.dart';
import 'document_picker.dart';
import 'identity_models.dart';
import 'kyc_widgets.dart';

/// Documents for verification (U5, 2026-10-25), each uploaded on its own as soon as the customer
/// has it. The list and every document's state come from the server's checklist; a document can be
/// sent only when the server says so (`can_upload`: missing or rejected).
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const _uploadFields = [
    ('front_image', 'Ghana Card front'),
    ('back_image', 'Ghana Card back'),
    ('salary_certificate', 'Salary certificate'),
    ('bank_statement', 'Bank statement (3 months)'),
  ];

  KycChecklist? _checklist;
  String? _loadError;
  String? _uploading; // the field being sent
  final Map<String, String> _errors = {}; // per document

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final s = await AppScope.of(context).customer.kycDetails();
      if (mounted) setState(() => _checklist = s.checklist);
    } catch (e) {
      if (mounted) setState(() => _loadError = errorText(e, "Couldn't load your documents."));
    }
  }

  Future<void> _upload(KycDocument d) async {
    if (_uploading != null || !d.canUpload) return;
    final scope = AppScope.of(context);
    setState(() => _errors.remove(d.field));
    try {
      final file = await (scope.documents ?? DevicePicker()).pick(context, label: d.label);
      if (file == null || !mounted) return;
      final problem = documentFileError(file);
      if (problem != null) {
        setState(() => _errors[d.field] = problem);
        return;
      }
      setState(() => _uploading = d.field);
      final message = await scope.customer.uploadDocument(d.field, file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (e) {
      // 400 (type or size) and 409 (already in review or verified) come back as the server's words
      if (mounted) setState(() => _errors[d.field] = errorText(e, "Couldn't upload that. Please try again."));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _checklist;
    final serverDocuments = {for (final d in c?.documents ?? <KycDocument>[]) d.field: d};
    final documents = [
      for (final (field, label) in _uploadFields)
        serverDocuments[field] ?? KycDocument(field: field, label: label, status: 'missing', rejectionReason: null, canUpload: true),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Upload documents')),
      body: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: pagePadding,
                children: [
                  if (_loadError != null)
                    const Note('Document status is unavailable right now. You can still upload a file and refresh to check its review status.', key: Key('docs-status-unavailable'), icon: LucideIcons.circleAlert, tone: NoteTone.warn)
                  else if (c == null)
                    const Center(child: CircularProgressIndicator())
                  else if (c.documentsToUpload.isNotEmpty)
                    Note(
                      'Still needed: ${c.documentsToUpload.join(', ')}. Upload each one as soon as you have it.',
                      key: const Key('docs-still-needed'),
                      icon: LucideIcons.listChecks,
                      tone: NoteTone.warn,
                    )
                  else if (c.documents.isNotEmpty)
                    const Note('All your documents are uploaded. The team reviews each one.', tone: NoteTone.success),
                  const SizedBox(height: Tp.s3),
                  VCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Lined([for (final d in documents) _row(d)]),
                  ),
                  const SizedBox(height: Tp.s3),
                  Text(
                    'Photos (JPG, PNG, WEBP) or PDF, up to 5 MB each. Make sure every corner is in the picture and the '
                    'writing is easy to read.',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(KycDocument d) {
    final t = Theme.of(context).textTheme;
    final busy = _uploading == d.field;
    final error = _errors[d.field];
    return Padding(
      key: Key('doc-${d.field}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText, size: 20, color: Tp.navy2),
              const SizedBox(width: Tp.s3),
              Expanded(child: Text(d.label, style: t.titleSmall)),
              documentChip(d),
            ],
          ),
          if (d.status == 'rejected' && d.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Why: ${d.rejectionReason}',
              key: Key('doc-reason-${d.field}'),
              style: t.bodySmall?.copyWith(color: Tp.error),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error,
              key: Key('doc-error-${d.field}'),
              style: t.bodySmall?.copyWith(color: Tp.error),
            ),
          ],
          if (d.canUpload) ...[
            const SizedBox(height: Tp.s2),
            OutlinedButton.icon(
              key: Key('doc-upload-${d.field}'),
              onPressed: _uploading != null ? null : () => _upload(d),
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.upload, size: 18),
              label: Text(
                busy
                    ? 'Uploading…'
                    : d.status == 'rejected'
                    ? 'Send a new one'
                    : 'Upload',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
