import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/evolution/evolution_providers.dart';
import 'teacher_intervention_intelligence.dart';

final teacherInterventionSuggestionsProvider =
    Provider<AsyncValue<List<TeacherInterventionSuggestion>>>((ref) {
  final insights = ref.watch(teacherAssistantInsightsProvider);
  return insights.whenData(buildTeacherInterventionSuggestions);
});

final teacherInterventionSummaryProvider =
    Provider<AsyncValue<TeacherInterventionSummary>>((ref) {
  final insights = ref.watch(teacherAssistantInsightsProvider);
  return insights.whenData((data) {
    final suggestions = buildTeacherInterventionSuggestions(data);
    final classActions = buildClassLevelInterventionActions(data);
    return summarizeTeacherInterventions(suggestions, classActions);
  });
});
