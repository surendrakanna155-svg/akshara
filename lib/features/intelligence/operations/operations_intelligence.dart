import '../../evolution/evolution_models.dart';
import '../student_success/student_success_models.dart';

/// P2 operations intelligence stubs — reshuffle, continuity, workflow (INTEL-07–10 program).

enum OperationsHintKind {
  sectionBalance('Section balance'),
  teacherContinuity('Teacher continuity'),
  workflowAutomation('Workflow automation');

  const OperationsHintKind(this.label);

  final String label;
}

class OperationsIntelligenceHint {
  const OperationsIntelligenceHint({
    required this.kind,
    required this.title,
    required this.detail,
    required this.priorityScore,
    required this.suggestedAction,
  });

  final OperationsHintKind kind;
  final String title;
  final String detail;
  final int priorityScore;
  final String suggestedAction;
}

class OperationsIntelligenceSummary {
  const OperationsIntelligenceSummary({
    required this.totalHints,
    required this.sectionBalanceCount,
    required this.teacherContinuityCount,
    required this.workflowCount,
    required this.topHints,
  });

  final int totalHints;
  final int sectionBalanceCount;
  final int teacherContinuityCount;
  final int workflowCount;
  final List<OperationsIntelligenceHint> topHints;
}

List<OperationsIntelligenceHint> buildSectionBalanceHints(
  List<StudentSuccessSnapshot> snapshots,
) {
  final byClassSection = <String, int>{};
  for (final snapshot in snapshots) {
    final key = '${snapshot.className}|${snapshot.sectionName ?? 'A'}';
    byClassSection[key] = (byClassSection[key] ?? 0) + 1;
  }

  if (byClassSection.length < 2) return const [];

  final counts = byClassSection.values.toList()..sort();
  final min = counts.first;
  final max = counts.last;
  if (max - min < 5) return const [];

  final overloaded = byClassSection.entries.where((e) => e.value == max).map((e) => e.key).first;
  final underloaded = byClassSection.entries.where((e) => e.value == min).map((e) => e.key).first;

  return [
    OperationsIntelligenceHint(
      kind: OperationsHintKind.sectionBalance,
      title: 'Section size imbalance detected',
      detail: 'Overloaded $overloaded ($max students) vs $underloaded ($min students).',
      priorityScore: ((max - min) * 2).clamp(10, 90),
      suggestedAction:
          'Review student reshuffle candidates to balance sections before next term.',
    ),
  ];
}

List<OperationsIntelligenceHint> buildTeacherContinuityHints(
  TeacherAssistantInsights insights,
) {
  if (insights.weakTopics.length < 2 && insights.riskStudents.length < 3) {
    return const [];
  }

  final classLabel = insights.scopedClassName ?? 'All classes';
  return [
    OperationsIntelligenceHint(
      kind: OperationsHintKind.teacherContinuity,
      title: 'Teacher continuity review — $classLabel',
      detail:
          '${insights.riskStudents.length} at-risk students and ${insights.weakTopics.length} weak topics flagged.',
      priorityScore: (insights.riskStudents.length * 8 + insights.weakTopics.length * 5).clamp(15, 85),
      suggestedAction:
          'Preserve subject-teacher pairing for weak topics; plan substitute coverage for interventions.',
    ),
  ];
}

List<OperationsIntelligenceHint> buildWorkflowAutomationHints(
  List<OperationsActionItem> actions,
) {
  return actions
      .map(
        (action) => OperationsIntelligenceHint(
          kind: OperationsHintKind.workflowAutomation,
          title: action.title,
          detail: '${action.module} · ${action.actionType} · ${action.severity} severity',
          priorityScore: _severityScore(action.severity),
          suggestedAction: 'Automate ${action.actionType} workflow for ${action.module}.',
        ),
      )
      .toList(growable: false);
}

int _severityScore(String severity) {
  final normalized = severity.toLowerCase();
  if (normalized.contains('critical') || normalized.contains('high')) return 80;
  if (normalized.contains('medium')) return 55;
  return 30;
}

List<OperationsIntelligenceHint> buildOperationsIntelligenceHints({
  required List<StudentSuccessSnapshot> snapshots,
  required TeacherAssistantInsights teacherInsights,
  required List<OperationsActionItem> operationsActions,
}) {
  final hints = <OperationsIntelligenceHint>[
    ...buildSectionBalanceHints(snapshots),
    ...buildTeacherContinuityHints(teacherInsights),
    ...buildWorkflowAutomationHints(operationsActions),
  ]..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

  return hints;
}

OperationsIntelligenceSummary summarizeOperationsHints(List<OperationsIntelligenceHint> hints) {
  return OperationsIntelligenceSummary(
    totalHints: hints.length,
    sectionBalanceCount: hints.where((h) => h.kind == OperationsHintKind.sectionBalance).length,
    teacherContinuityCount:
        hints.where((h) => h.kind == OperationsHintKind.teacherContinuity).length,
    workflowCount: hints.where((h) => h.kind == OperationsHintKind.workflowAutomation).length,
    topHints: hints.take(10).toList(growable: false),
  );
}
