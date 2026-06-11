import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/api/intelligence/hybrid_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/intelligence/intelligence_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockIntelligenceRepository', () {
    const query = RepositoryQuery.demo;
    final repo = MockIntelligenceRepository();

    test('lists student and class risks', () async {
      final risks = await repo.listStudentRisks(query: query);
      expect(risks, hasLength(2));
      expect(risks.first.riskLevel, StudentRiskLevel.high);

      final classes = await repo.listClassRisks(query: query);
      expect(classes, hasLength(1));
      expect(classes.first.highCount, 1);
    });

    test('generates communication and parent guidance', () async {
      final drafts = await repo.generateCommunication(
        query: query,
        scenario: CommunicationScenario.absent,
        studentName: 'Test',
        languages: const [IntelLanguage.english, IntelLanguage.telugu],
      );
      expect(drafts, hasLength(2));

      final guidance = await repo.generateParentGuidance(
        query: query,
        studentId: 'student_1',
        mode: GuidanceMode.monthly,
        inputs: const {'attendancePercent': 70},
      );
      expect(guidance.strengths, isNotEmpty);
    });

    test('returns teacher and principal centers', () async {
      final teacher = await repo.getTeacherSuccessCenter(query: query);
      expect(teacher.riskStudents, greaterThan(0));
      expect(teacher.dailyActionPlan, isNotEmpty);

      final principal = await repo.getPrincipalCenter(query: query);
      expect(principal.schoolHealthScore, greaterThan(0));
      expect(principal.classSummaries, isNotEmpty);
      expect(principal.executiveDashboard, isNotNull);
    });

    test('publishes parent guidance and resolves principal query', () async {
      final guidance = await repo.generateParentGuidance(
        query: query,
        studentId: 'student_1',
        mode: GuidanceMode.weekly,
        publish: true,
      );
      expect(guidance.status, 'published');

      final queryResult = await repo.queryPrincipal(
        query: query,
        queryText: 'students below 75% attendance',
      );
      expect(queryResult.intent, 'low_attendance');
      expect(queryResult.count, greaterThan(0));
    });

    test('communication uses parent preferred language and fee context', () async {
      final drafts = await repo.generateCommunication(
        query: query,
        scenario: CommunicationScenario.feeReminder,
        parentPreferredLanguage: IntelLanguage.telugu,
        feeAmount: '8000',
        dueDate: '1 Jul',
        languages: const [IntelLanguage.english],
      );
      expect(drafts.first.language, IntelLanguage.telugu);
      expect(drafts.first.professional, contains('8000'));
    });

    test('returns student success and exam intelligence data', () async {
      final dashboard = await repo.getStudentSuccessDashboard(query: query);
      expect(dashboard.studentsAnalyzed, greaterThan(0));

      final predictions = await repo.listStudentSuccessPredictions(query: query);
      expect(predictions.first.dropoutProbability, greaterThan(0));

      final analytics = await repo.getExamAnalytics(query: query);
      expect(analytics.averageScorePercent, greaterThan(0));

      final weak = await repo.getWeakChapters(query: query);
      expect(weak, isNotEmpty);
    });
  });

  group('intelligence repository provider', () {
    test('uses mock when API flag disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(intelligenceRepositoryProvider),
        isA<MockIntelligenceRepository>(),
      );
    });

    test('uses hybrid when global and module flags enabled', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          intelligenceApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(intelligenceRepositoryProvider),
        isA<HybridIntelligenceRepository>(),
      );
    });
  });
}
