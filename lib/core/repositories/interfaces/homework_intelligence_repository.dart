import '../../../features/homework_intelligence/homework_intelligence_models.dart';
import '../repository_query.dart';

abstract class HomeworkIntelligenceRepository {
  Future<HomeworkIntelligencePlan> getPlan({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
    String? sectionName,
  });

  Future<({String runId, HomeworkIntelligencePlan plan, int? homeworkCount})> generate({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
    bool apply = false,
  });
}
