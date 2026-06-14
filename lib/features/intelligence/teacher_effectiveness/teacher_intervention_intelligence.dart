import '../../evolution/evolution_models.dart';

/// Deterministic teacher intervention tiers (INTEL-06).
enum InterventionPriority {
  urgent('Urgent', 3),
  high('High', 2),
  medium('Medium', 1),
  low('Low', 0);

  const InterventionPriority(this.label, this.sortOrder);

  final String label;
  final int sortOrder;
}

class TeacherInterventionSuggestion {
  const TeacherInterventionSuggestion({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.priority,
    required this.triggerReason,
    required this.suggestedIntervention,
    required this.estimatedImpact,
  });

  final String studentId;
  final String studentName;
  final String className;
  final InterventionPriority priority;
  final String triggerReason;
  final String suggestedIntervention;
  final String estimatedImpact;
}

class TeacherInterventionSummary {
  const TeacherInterventionSummary({
    required this.totalSuggestions,
    required this.urgentCount,
    required this.highCount,
    required this.classLevelActions,
    required this.topSuggestions,
  });

  final int totalSuggestions;
  final int urgentCount;
  final int highCount;
  final List<String> classLevelActions;
  final List<TeacherInterventionSuggestion> topSuggestions;
}

InterventionPriority classifyInterventionPriority(Map<String, dynamic> riskStudent) {
  final level = riskStudent['riskLevel']?.toString().toLowerCase() ?? '';
  if (level.contains('critical') || level == 'high') {
    return InterventionPriority.urgent;
  }
  if (level.contains('high') || level.contains('medium')) {
    return InterventionPriority.high;
  }
  if (level.contains('medium') || level.contains('moderate')) {
    return InterventionPriority.medium;
  }
  return InterventionPriority.low;
}

String _interventionForPriority(InterventionPriority priority, String reason) {
  return switch (priority) {
    InterventionPriority.urgent =>
      'Schedule 1:1 remediation this week and notify parent about $reason.',
    InterventionPriority.high =>
      'Assign peer mentor and review homework submissions for $reason.',
    InterventionPriority.medium =>
      'Add targeted practice worksheet and monitor progress for $reason.',
    InterventionPriority.low => 'Include in weekly progress check-in.',
  };
}

String _impactForPriority(InterventionPriority priority) => switch (priority) {
      InterventionPriority.urgent => 'High — prevents further decline within 2 weeks.',
      InterventionPriority.high => 'Moderate — expected improvement in 3–4 weeks.',
      InterventionPriority.medium => 'Steady — supports gradual recovery.',
      InterventionPriority.low => 'Preventive — maintains current trajectory.',
    };

TeacherInterventionSuggestion suggestionFromRiskStudent(Map<String, dynamic> riskStudent) {
  final priority = classifyInterventionPriority(riskStudent);
  final reason = riskStudent['topReason']?.toString() ?? 'academic risk';
  return TeacherInterventionSuggestion(
    studentId: riskStudent['studentId']?.toString() ?? riskStudent['id']?.toString() ?? '',
    studentName: riskStudent['studentName']?.toString() ?? 'Student',
    className: riskStudent['className']?.toString() ?? 'Unknown',
    priority: priority,
    triggerReason: reason,
    suggestedIntervention: _interventionForPriority(priority, reason),
    estimatedImpact: _impactForPriority(priority),
  );
}

List<TeacherInterventionSuggestion> buildTeacherInterventionSuggestions(
  TeacherAssistantInsights insights, {
  InterventionPriority minimumPriority = InterventionPriority.medium,
}) {
  final suggestions = insights.riskStudents.map(suggestionFromRiskStudent).toList()
    ..sort((a, b) {
      final priorityCompare = b.priority.sortOrder.compareTo(a.priority.sortOrder);
      if (priorityCompare != 0) return priorityCompare;
      return a.studentName.compareTo(b.studentName);
    });

  return suggestions
      .where((s) => s.priority.sortOrder >= minimumPriority.sortOrder)
      .toList(growable: false);
}

List<String> buildClassLevelInterventionActions(TeacherAssistantInsights insights) {
  final actions = <String>[];
  if (insights.weakTopics.isNotEmpty) {
    actions.add(
      'Re-teach weak topics: ${insights.weakTopics.take(3).join(', ')}.',
    );
  }
  if (insights.homeworkConcerns.isNotEmpty) {
    actions.add(
      'Review homework patterns: ${insights.homeworkConcerns.first}.',
    );
  }
  for (final action in insights.suggestedActions.take(3)) {
    actions.add(action);
  }
  for (final lesson in insights.lessonPlanSuggestions.take(2)) {
    actions.add('Lesson plan: $lesson');
  }
  return actions;
}

TeacherInterventionSummary summarizeTeacherInterventions(
  List<TeacherInterventionSuggestion> suggestions,
  List<String> classLevelActions,
) {
  return TeacherInterventionSummary(
    totalSuggestions: suggestions.length,
    urgentCount: suggestions.where((s) => s.priority == InterventionPriority.urgent).length,
    highCount: suggestions.where((s) => s.priority == InterventionPriority.high).length,
    classLevelActions: classLevelActions,
    topSuggestions: suggestions.take(12).toList(growable: false),
  );
}
