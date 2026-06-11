import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'teacher_effectiveness_models.dart';

final teacherEffectivenessQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final lessonEffectivenessScoresProvider =
    FutureProvider<List<LessonEffectivenessScore>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).getLessonEffectivenessScores(
        query: ref.watch(teacherEffectivenessQueryProvider),
      );
});

final topicMasteryAnalyticsProvider = FutureProvider<List<TopicMasteryEntry>>((ref) async {
  return ref.read(intelligenceRepositoryProvider).getTopicMasteryAnalytics(
        query: ref.watch(teacherEffectivenessQueryProvider),
      );
});

final teacherPerformanceInsightsProvider =
    FutureProvider<TeacherPerformanceInsights>((ref) async {
  return ref.read(intelligenceRepositoryProvider).getTeacherPerformanceInsights(
        query: ref.watch(teacherEffectivenessQueryProvider),
      );
});

final teacherPlanningCenterProvider = FutureProvider<TeacherPlanningCenter>((ref) async {
  return ref.read(intelligenceRepositoryProvider).getTeacherPlanningCenter(
        query: ref.watch(teacherEffectivenessQueryProvider),
      );
});
