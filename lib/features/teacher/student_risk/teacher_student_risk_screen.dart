import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/communication/parent_communication_models.dart';
import '../../../core/communication/teacher_parent_templates.dart';
import '../../../core/communication/teacher_student_risk_service.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/security/permissions.dart';
import '../../../router/route_names.dart';
import '../../../router/student360_navigation.dart';
import '../../../shared/widgets/akshara_view_action.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../communication/teacher_parent_communication_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';

/// Class-teacher student 360 risk view (mobile).
class TeacherStudentRiskScreen extends ConsumerWidget {
  const TeacherStudentRiskScreen({
    super.key,
    required this.sisStudentId,
  });

  final String sisStudentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync =
        ref.watch(teacherStudentRiskSnapshotProvider(sisStudentId));
    return snapshotAsync.when(
      loading: () => const Scaffold(
        body: AksharaLoadingState(),
      ),
      error: (error, _) => Scaffold(
        appBar: const AksharaAppBar(titleText: 'Student risk'),
        body: AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(error),
          onRetry: () => ref.invalidate(
            teacherStudentRiskSnapshotProvider(sisStudentId),
          ),
        ),
      ),
      // E2E-011 — no live dossier means no dossier. The screen says so instead
      // of rendering a fixture-composed attendance / marks / homework / fees
      // profile for a student it knows nothing about.
      data: (snapshot) => snapshot == null
          ? Scaffold(
              appBar: const AksharaAppBar(titleText: 'Student risk'),
              body: AksharaEmptyState(
                title: 'Risk profile not available',
                message:
                    'This student has no risk profile from the intelligence '
                    'service yet. Attendance, marks, homework and fee details '
                    'will appear here once they are published.',
                icon: Icons.insights_outlined,
                actionLabel: 'Open Student 360',
                onAction: () => openStudent360(context, sisStudentId),
              ),
            )
          : _buildContent(context, ref, snapshot),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    TeacherStudentRiskSnapshot snapshot,
  ) {
    // PRA-P0-17 (S0/T2-F): provider is now async (live endpoint).
    final timeline = ref
            .watch(studentCommunicationTimelineProvider(sisStudentId))
            .valueOrNull ??
        const [];
    final concerns = ref
            .watch(
              pendingSubjectConcernsProvider,
            )
            .valueOrNull
            ?.where((c) => c.sisStudentId == sisStudentId)
            .toList() ??
        const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: snapshot.studentName.isEmpty
            ? 'Student risk'
            : snapshot.studentName,
        subtitle: _identitySubtitle(snapshot),
      ),
      // DS V2 P4 — premium persona canvas behind the risk 360. The headline is a
      // categorical risk LEVEL (not a %), so no ring — attendance/homework %s are
      // secondary detail rows.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            AksharaSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Risk: ${snapshot.riskLevel.name}',
                      style: context.aksharaText.titleMedium),
                  Text(snapshot.riskFactors.join(' · ')),
                ],
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            // E2E-011 — every row is an honest unknown until its real source is
            // wired. `_Row` renders "Not available" for a null value; it never
            // shows a constant.
            _Row('Attendance', _attendanceLabel(snapshot)),
            _Row(
              'Homework',
              snapshot.homeworkCompletionPercent == null
                  ? null
                  : '${snapshot.homeworkCompletionPercent}% completion',
            ),
            _Row(
              'Behaviour',
              snapshot.behaviorIncidentCount == null
                  ? null
                  : '${snapshot.behaviorIncidentCount} incident(s)',
            ),
            _Row('Fees', snapshot.feePendingLabel),
            const SizedBox(height: AksharaSpacing.s2),
            const AksharaSectionHeader(title: 'Subject performance'),
            if (snapshot.subjectPerformance.isEmpty)
              const _Row('Subject marks', null)
            else
              for (final entry in snapshot.subjectPerformance.entries)
                _Row(entry.key, entry.value),
            const SizedBox(height: AksharaSpacing.s3),
            const AksharaSectionHeader(title: 'Communication history'),
            Text(
                '${snapshot.communicationHistoryCount} sent · ${concerns.length} pending review'),
            for (final record in timeline.take(3))
              ListTile(
                dense: true,
                title: Text(record.originalMessage, maxLines: 2),
                subtitle: Text('${record.senderName} · ${record.sentAt}'),
              ),
            if (concerns.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s3),
              const AksharaSectionHeader(title: 'Subject teacher flags'),
              for (final concern in concerns)
                ListTile(
                  title: Text('${concern.subject}: ${concern.category.label}'),
                  subtitle: Text(concern.observation),
                ),
            ],
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: 'Suggested templates'),
            _TemplateChip(
              label: 'Attendance',
              onTap: () => _openComms(
                ref,
                context,
                ParentCommunicationReason.attendanceLow,
                ParentCommunicationTone.concerned,
              ),
            ),
            _TemplateChip(
              label: 'Low marks',
              onTap: () => _openComms(
                ref,
                context,
                ParentCommunicationReason.marksLow,
                ParentCommunicationTone.encouragement,
              ),
            ),
            _TemplateChip(
              label: 'Homework',
              onTap: () => _openComms(
                ref,
                context,
                ParentCommunicationReason.homeworkMissing,
                ParentCommunicationTone.gentleReminder,
              ),
            ),
            _TemplateChip(
              label: 'Appreciation',
              onTap: () => _openComms(
                ref,
                context,
                ParentCommunicationReason.appreciation,
                ParentCommunicationTone.goodPerformance,
              ),
            ),
            _TemplateChip(
              label: 'Discipline',
              onTap: () => _openComms(
                ref,
                context,
                ParentCommunicationReason.disciplineIssue,
                ParentCommunicationTone.informational,
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            AksharaViewAction(
              permission: Permission.viewStudent360,
              child: OutlinedButton.icon(
                onPressed: () => openStudent360(context, sisStudentId),
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Open Student 360'),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            FilledButton(
              onPressed: () => _openComms(
                ref,
                context,
                ParentCommunicationReason.generalProgress,
                ParentCommunicationTone.goodPerformance,
              ),
              child: const Text('Communicate with parent'),
            ),
          ],
        ),
      ),
    );
  }

  static String? _identitySubtitle(TeacherStudentRiskSnapshot snapshot) {
    final parts = <String>[
      if (snapshot.classLabel.isNotEmpty) snapshot.classLabel,
      if (snapshot.rollNo.isNotEmpty) 'Roll ${snapshot.rollNo}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? _attendanceLabel(TeacherStudentRiskSnapshot snapshot) {
    final percent = snapshot.attendancePercent;
    if (percent == null) return null;
    final trend = snapshot.attendanceTrend;
    return trend == null ? '$percent%' : '$percent% · $trend';
  }

  void _openComms(
    WidgetRef ref,
    BuildContext context,
    ParentCommunicationReason reason,
    ParentCommunicationTone tone,
  ) {
    ref.read(teacherCommunicationSelectedStudentProvider.notifier).state =
        sisStudentId;
    ref.read(teacherCommunicationReasonProvider.notifier).state = reason;
    ref.read(teacherCommunicationToneProvider.notifier).state = tone;
    context.push(RouteNames.teacherParentCommunication);
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;

  /// Null renders the honest unknown, never a placeholder figure.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: value == null
          ? Text(
              'Not available',
              style: context.aksharaText.bodyMedium.copyWith(
                color: context.colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          : Text(value, style: context.aksharaText.bodyMedium),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: ActionChip(label: Text(label), onPressed: onTap),
    );
  }
}
