import '../../../features/homework_intelligence/homework_intelligence_models.dart';
import '../interfaces/homework_intelligence_repository.dart';
import '../repository_query.dart';

class MockHomeworkIntelligenceRepository implements HomeworkIntelligenceRepository {
  HomeworkIntelligencePlan _demoPlan(String className, String subjectName, String examType) {
    return HomeworkIntelligencePlan(
      className: className,
      subjectName: subjectName,
      examType: examType,
      weakTopics: const [
        {'topic': 'Linear equations', 'chapter': 'Algebra', 'avgMarksPercent': 48},
        {'topic': 'Geometry basics', 'chapter': 'Geometry', 'avgMarksPercent': 52},
      ],
      riskStudents: const [
        {
          'studentId': 'student_1',
          'studentName': 'Arjun Reddy',
          'riskLevel': 'high',
          'riskScore': 78,
          'topReason': 'Low attendance',
        },
      ],
      revisionSuggestions: const [
        'Revision focus: Linear equations (Algebra) — class average 48%',
      ],
      worksheetSuggestions: const [
        {'topic': 'Linear equations', 'assignmentType': 'revision_worksheet', 'reason': 'Weak performance'},
      ],
      recommendedHomework: const [
        {'topic': 'Linear equations', 'title': 'Mathematics homework — Linear equations', 'assignmentType': 'homework'},
      ],
      recommendedQuestionPapers: const [
        {'examType': 'unit_test', 'chapters': ['Algebra'], 'reason': 'Target weak chapters'},
      ],
      classRecommendations: const [
        '2 weak topic(s) identified.',
        '1 student(s) flagged above low risk.',
      ],
      studentRecommendations: const [
        {'studentId': 'student_1', 'actions': ['Assign targeted homework for Low attendance']},
      ],
      revisionPlans: const [
        {'studentId': 'student_1', 'plan': 'Daily 30-minute revision on Linear equations'},
      ],
      interventionPlans: const [
        {'studentId': 'student_1', 'intervention': 'Teacher check-in', 'owner': 'teacher'},
      ],
    );
  }

  @override
  Future<HomeworkIntelligencePlan> getPlan({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
    String? sectionName,
  }) async =>
      _demoPlan(className, subjectName, examType);

  @override
  Future<({String runId, HomeworkIntelligencePlan plan, int? homeworkCount})> generate({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
    bool apply = false,
  }) async {
    final plan = _demoPlan(className, subjectName, examType);
    return (runId: 'hw_run_demo_1', plan: plan, homeworkCount: apply ? 1 : null);
  }
}
