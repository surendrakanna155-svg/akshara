import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/intelligence/intelligence_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('school completion intelligence mock covers guidance publish and principal query', () async {
    const query = RepositoryQuery.demo;
    final repo = MockIntelligenceRepository();

    final guidance = await repo.generateParentGuidance(
      query: query,
      studentId: 'student_1',
      mode: GuidanceMode.examReview,
      language: IntelLanguage.hindi,
      publish: true,
    );
    expect(guidance.status, 'published');
    expect(guidance.printable, isTrue);

    final principal = await repo.getPrincipalCenter(query: query);
    expect(principal.executiveDashboard?.feeCollectionTrend, isNotEmpty);

    final teacher = await repo.getTeacherSuccessCenter(query: query);
    expect(teacher.dailyActionPlan.first.category, isNotEmpty);
  });
}
