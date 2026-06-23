import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'education_models.dart';
import 'education_pdf_service.dart';
import 'education_provider.dart';

/// Batch 8c — paper detail with the AI-candidate moderation queue and the
/// submit → review → approve → publish governance lifecycle.
class QuestionPaperDetailScreen extends ConsumerWidget {
  const QuestionPaperDetailScreen({super.key, required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(paperDetailProvider(paperId));
    final canManage = ref.watch(educationCanManageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Question Paper')),
      body: detail.when(
        data: (d) => _PaperBody(paperId: paperId, detail: d, canManage: canManage),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _PaperBody extends ConsumerWidget {
  const _PaperBody({
    required this.paperId,
    required this.detail,
    required this.canManage,
  });

  final String paperId;
  final QuestionPaperDetail detail;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paper = detail.paper;
    final pending = detail.pendingAiItems;
    final placedMarks = detail.items.fold<int>(0, (sum, item) => sum + item.marks);
    final unfilledMarks = paper.totalMarks - placedMarks;
    final reviews = ref.watch(paperReviewsProvider(paperId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(paper.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(label: Text(_reviewStatusLabel(paper.reviewStatus))),
            Chip(label: Text('${paper.totalMarks} marks')),
            Chip(label: Text(_programTrackLabel(paper.programTrack))),
            Chip(label: Text('Bank ${paper.bankReuseCount ?? 0} / AI ${paper.aiGeneratedCount ?? 0}')),
          ],
        ),
        const SizedBox(height: 12),

        if (unfilledMarks > 0)
          _Banner(
            key: QaTestKeys.educationUnfilledMarksBanner,
            icon: Icons.report_gmailerrorred_outlined,
            color: Colors.orange,
            text: '$unfilledMarks marks unfilled — the bank could not cover the full '
                'blueprint and AI did not author the remaining slots. Add bank '
                'questions for these chapters or regenerate with AI gap-fill on.',
          ),

        if (pending.isNotEmpty)
          _Banner(
            icon: Icons.smart_toy_outlined,
            color: Colors.deepPurple,
            text: '${pending.length} AI candidate(s) awaiting moderation. '
                'Approve or reject each before this paper can be published.',
          ),

        if (pending.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('AI moderation queue', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ...pending.map((item) => _ModerationCard(
                paperId: paperId,
                item: item,
                canManage: canManage,
              )),
          const Divider(height: 32),
        ],

        Text('Questions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ...detail.items.map((item) => _QuestionTile(item: item)),

        const Divider(height: 32),
        _GovernanceActions(
          paperId: paperId,
          paper: paper,
          hasPendingAi: pending.isNotEmpty,
          canManage: canManage,
        ),

        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print / export'),
            onPressed: () => EducationPdfService.printQuestionPaper(detail).catchError((_) {}),
          ),
        ),

        const SizedBox(height: 16),
        Text('Review history', style: Theme.of(context).textTheme.titleMedium),
        reviews.when(
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Not yet submitted for review.'),
                )
              : Column(
                  children: items
                      .map((r) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.history),
                            title: Text('Round ${r.roundNumber} • ${r.status}'),
                            subtitle: r.comments == null ? null : Text(r.comments!),
                          ))
                      .toList(),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text('Error loading reviews: $e'),
        ),
      ],
    );
  }
}

class _ModerationCard extends ConsumerWidget {
  const _ModerationCard({
    required this.paperId,
    required this.item,
    required this.canManage,
  });

  final String paperId;
  final QuestionPaperItem item;
  final bool canManage;

  Future<void> _moderate(BuildContext context, WidgetRef ref, String decision) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(educationMutationsProvider.notifier).moderateItem(
            paperId,
            item.id!,
            decision,
          );
      messenger.showSnackBar(
        SnackBar(content: Text('AI candidate $decision')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q${item.questionNumber} • ${item.questionType.name} • ${item.marks} marks'),
            const SizedBox(height: 4),
            Text(item.questionText),
            if (item.options.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...item.options.map((o) => Text('• $o')),
            ],
            if (item.answerText != null && item.answerText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Answer: ${item.answerText}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (canManage && item.id != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: QaTestKeys.educationModerateRejectButton(item.id!),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    onPressed: () => _moderate(context, ref, 'rejected'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: QaTestKeys.educationModerateApproveButton(item.id!),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    onPressed: () => _moderate(context, ref, 'approved'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.item});

  final QuestionPaperItem item;

  @override
  Widget build(BuildContext context) {
    final rejected = item.source == 'ai_candidate' && item.reviewStatus == 'rejected';
    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text('${item.questionNumber}')),
      title: Text(
        item.questionText,
        style: rejected ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Text('${item.questionType.name} • ${item.marks} marks • ${item.source}'),
    );
  }
}

class _GovernanceActions extends ConsumerWidget {
  const _GovernanceActions({
    required this.paperId,
    required this.paper,
    required this.hasPendingAi,
    required this.canManage,
  });

  final String paperId;
  final QuestionPaperSummary paper;
  final bool hasPendingAi;
  final bool canManage;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canManage) return const SizedBox.shrink();
    final notifier = ref.read(educationMutationsProvider.notifier);
    final status = paper.reviewStatus;

    final buttons = <Widget>[];

    if (status == EduPaperReviewStatus.draft ||
        status == EduPaperReviewStatus.changesRequested) {
      buttons.add(FilledButton.icon(
        key: QaTestKeys.educationSubmitPaperButton,
        icon: const Icon(Icons.send_outlined),
        label: const Text('Submit for review'),
        onPressed: hasPendingAi
            ? null
            : () => _run(context, ref, () => notifier.submitPaper(paperId),
                'Paper submitted for review'),
      ));
    }

    if (status == EduPaperReviewStatus.submitted) {
      buttons.add(OutlinedButton.icon(
        key: QaTestKeys.educationReviewChangesButton,
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Request changes'),
        onPressed: () => _requestChanges(context, ref, notifier),
      ));
      buttons.add(FilledButton.icon(
        key: QaTestKeys.educationReviewApproveButton,
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Approve'),
        onPressed: () => _run(context, ref,
            () => notifier.reviewPaper(paperId, 'approved'), 'Paper approved'),
      ));
    }

    if (status == EduPaperReviewStatus.approved) {
      buttons.add(FilledButton.icon(
        icon: const Icon(Icons.publish_outlined),
        label: const Text('Publish'),
        onPressed: hasPendingAi
            ? null
            : () => _run(context, ref, () => notifier.publishPaper(paperId),
                'Paper published'),
      ));
    }

    // A plain draft with no AI candidates can still be published directly
    // (preserves the existing 100%-bank flow).
    if (status == EduPaperReviewStatus.draft && !hasPendingAi) {
      buttons.add(OutlinedButton.icon(
        icon: const Icon(Icons.publish_outlined),
        label: const Text('Publish now'),
        onPressed: () => _run(context, ref, () => notifier.publishPaper(paperId),
            'Paper published'),
      ));
    }

    if (buttons.isEmpty) {
      return Text('Status: ${_reviewStatusLabel(status)}',
          style: Theme.of(context).textTheme.bodyMedium);
    }

    return Wrap(spacing: 12, runSpacing: 8, children: buttons);
  }

  Future<void> _requestChanges(
    BuildContext context,
    WidgetRef ref,
    EducationMutationsNotifier notifier,
  ) async {
    final controller = TextEditingController();
    final comments = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request changes'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What needs to change?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (comments == null) return;
    if (!context.mounted) return;
    await _run(
      context,
      ref,
      () => notifier.reviewPaper(paperId, 'changes_requested', comments: comments),
      'Changes requested',
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _reviewStatusLabel(EduPaperReviewStatus status) => switch (status) {
      EduPaperReviewStatus.draft => 'Draft',
      EduPaperReviewStatus.submitted => 'Submitted',
      EduPaperReviewStatus.changesRequested => 'Changes requested',
      EduPaperReviewStatus.approved => 'Approved',
      EduPaperReviewStatus.published => 'Published',
      EduPaperReviewStatus.archived => 'Archived',
    };

String _programTrackLabel(EduProgramTrack track) => switch (track) {
      EduProgramTrack.board => 'Board',
      EduProgramTrack.jeeFoundation => 'JEE Foundation',
      EduProgramTrack.neetFoundation => 'NEET Foundation',
      EduProgramTrack.ntse => 'NTSE',
      EduProgramTrack.olympiad => 'Olympiad',
    };
