import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/tokens.dart';
import '../../ui/vault.dart';
import 'identity_models.dart';

/// "What's still needed" (U4/U5): the server's checklist, as two rows (Your details, Documents),
/// each opening its own screen. The app only shows what the server listed.
class KycChecklistCard extends StatelessWidget {
  const KycChecklistCard({super.key, required this.checklist, required this.onDetails, required this.onDocuments});
  final KycChecklist checklist;
  final VoidCallback onDetails;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    final c = checklist;
    final detailsDone = c.detailsMissing.isEmpty;
    final docsDone = c.documentsToUpload.isEmpty;
    final docsSub = [
      if (c.documentsToUpload.isNotEmpty) 'Still to upload: ${c.documentsToUpload.join(', ')}',
      if (c.documentsInReview.isNotEmpty) 'Waiting for review: ${c.documentsInReview.join(', ')}',
    ];
    return VCard(
      key: const Key('kyc-checklist'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Lined([
        _StepRow(
          key: const Key('kyc-step-details'),
          icon: LucideIcons.userPen,
          title: 'Your details',
          done: detailsDone,
          sub: detailsDone ? 'All added' : 'Still to add: ${c.detailsMissing.join(', ')}',
          onTap: onDetails,
        ),
        _StepRow(
          key: const Key('kyc-step-documents'),
          icon: LucideIcons.fileUp,
          title: 'Documents',
          done: docsDone,
          sub: docsSub.isEmpty ? 'All uploaded' : docsSub.join('\n'),
          onTap: onDocuments,
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.icon,
    required this.title,
    required this.done,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final bool done;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Tp.navy2),
              const SizedBox(width: Tp.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    Text(sub, style: t.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: Tp.s2),
              done
                  ? const VChip('Done', icon: LucideIcons.check, tone: NoteTone.success)
                  : const VChip('To do', tone: NoteTone.warn),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight, size: 18, color: Tp.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A document's state as words, an icon and a colour (U5).
VChip documentChip(KycDocument d) => switch (d.status) {
  'verified' => const VChip('Verified', icon: LucideIcons.badgeCheck, tone: NoteTone.success),
  'pending' => const VChip('Waiting for review', icon: LucideIcons.clock, tone: NoteTone.info),
  'rejected' => const VChip('Rejected', icon: LucideIcons.circleAlert, tone: NoteTone.error),
  _ => const VChip('Needed', tone: NoteTone.warn),
};
