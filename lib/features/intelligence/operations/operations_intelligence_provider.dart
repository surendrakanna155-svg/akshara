import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/evolution/evolution_providers.dart';
import '../student_success/student_success_provider.dart';
import 'operations_intelligence.dart';

final operationsIntelligenceHintsProvider =
    Provider<AsyncValue<List<OperationsIntelligenceHint>>>((ref) {
  final snapshots = ref.watch(studentSuccessPredictionsProvider);
  final teacher = ref.watch(teacherAssistantInsightsProvider);
  final actions = ref.watch(operationsActionsProvider);

  if (snapshots.isLoading || teacher.isLoading || actions.isLoading) {
    return const AsyncValue.loading();
  }
  if (snapshots.hasError) return AsyncValue.error(snapshots.error!, snapshots.stackTrace!);
  if (teacher.hasError) return AsyncValue.error(teacher.error!, teacher.stackTrace!);
  if (actions.hasError) return AsyncValue.error(actions.error!, actions.stackTrace!);

  return AsyncValue.data(
    buildOperationsIntelligenceHints(
      snapshots: snapshots.requireValue,
      teacherInsights: teacher.requireValue,
      operationsActions: actions.requireValue,
    ),
  );
});

final operationsIntelligenceSummaryProvider =
    Provider<AsyncValue<OperationsIntelligenceSummary>>((ref) {
  final hints = ref.watch(operationsIntelligenceHintsProvider);
  return hints.whenData(summarizeOperationsHints);
});
