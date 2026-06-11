import 'package:akshara_erp/core/repositories/api/intelligence/mapper/intelligence_mapper.dart';
import 'package:akshara_erp/core/repositories/interfaces/intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Student Success Intelligence contract', () {
    late MockIntelligenceRepository mockRepo;

    setUp(() {
      mockRepo = MockIntelligenceRepository();
    });

    test('mock implements IntelligenceRepository', () {
      expect(mockRepo, isA<IntelligenceRepository>());
    });

    test('dashboard returns analyzed students and risk counts', () async {
      final dashboard = await mockRepo.getStudentSuccessDashboard(query: query);
      expect(dashboard.studentsAnalyzed, greaterThan(0));
      expect(dashboard.insights, isNotEmpty);
      expect(dashboard.topRiskStudents, isNotEmpty);
    });

    test('predictions include dropout and attendance fields', () async {
      final items = await mockRepo.listStudentSuccessPredictions(query: query);
      expect(items, isNotEmpty);
      expect(items.first.dropoutProbability, greaterThan(0));
      expect(items.first.predictions, isNotEmpty);
    });

    test('mapper converts student success snapshot from API shape', () {
      final mapped = IntelligenceMapper.studentSuccessFromApi({
        'id': 'ss_1',
        'studentId': 'student_1',
        'studentName': 'Test Student',
        'className': 'Grade 8',
        'dropoutProbability': 65,
        'attendancePrediction': 70,
        'performanceDeclineScore': 40,
        'improvementScore': 55,
        'riskSignals': [
          {'code': 'dropout_risk', 'label': 'Elevated dropout risk', 'severity': 'high'},
        ],
        'predictions': {'dropoutRisk': 'Moderate — watchlist'},
      });
      expect(mapped.studentId, 'student_1');
      expect(mapped.dropoutProbability, 65);
      expect(mapped.riskSignals, hasLength(1));
    });

    test('improvements and interventions return tracking data', () async {
      final improvements = await mockRepo.listStudentImprovements(query: query);
      expect(improvements, isNotEmpty);
      expect(improvements.first.trend, isNotEmpty);

      final interventions = await mockRepo.listInterventionEffectiveness(query: query);
      expect(interventions, isNotEmpty);
      expect(interventions.first.interventionLabel, isNotEmpty);
    });

    test('exam intelligence analytics and weak chapters', () async {
      final analytics = await mockRepo.getExamAnalytics(query: query);
      expect(analytics.totalExams, greaterThan(0));
      expect(analytics.insights, isNotEmpty);

      final weak = await mockRepo.getWeakChapters(query: query);
      expect(weak, isNotEmpty);
      expect(weak.first.recommendation, isNotEmpty);

      final forecast = await mockRepo.getAcademicForecast(query: query);
      expect(forecast.predictedAvgPercent, greaterThan(0));
      expect(forecast.recommendations, isNotEmpty);

      final ranks = await mockRepo.getRankMovement(query: query);
      expect(ranks, isNotEmpty);
      expect(ranks.first.direction, isNotEmpty);
    });
  });
}
