import 'package:akshara_erp/features/intelligence/student_success/at_risk_student_intelligence.dart';
import 'package:akshara_erp/features/intelligence/student_success/student_success_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyAtRiskTier', () {
    test('marks high dropout as critical', () {
      const snapshot = StudentSuccessSnapshot(
        id: '1',
        studentId: 's1',
        studentName: 'Asha',
        className: '10-A',
        dropoutProbability: 82,
        attendancePrediction: 70,
        performanceDeclineScore: 40,
        improvementScore: 20,
        riskSignals: [
          {'label': 'Chronic absence', 'severity': 'high'},
        ],
        predictions: {},
      );

      expect(classifyAtRiskTier(snapshot), AtRiskTier.critical);
    });

    test('buildAtRiskProfiles filters medium tier and above', () {
      const low = StudentSuccessSnapshot(
        id: '1',
        studentId: 's1',
        studentName: 'Low',
        className: '8-A',
        dropoutProbability: 10,
        attendancePrediction: 95,
        performanceDeclineScore: 5,
        improvementScore: 80,
        riskSignals: [],
        predictions: {},
      );
      const high = StudentSuccessSnapshot(
        id: '2',
        studentId: 's2',
        studentName: 'High',
        className: '9-B',
        dropoutProbability: 68,
        attendancePrediction: 62,
        performanceDeclineScore: 55,
        improvementScore: 30,
        riskSignals: [
          {'label': 'Fee stress', 'severity': 'medium'},
        ],
        predictions: {},
      );

      final profiles = buildAtRiskProfiles([low, high]);
      expect(profiles, hasLength(1));
      expect(profiles.first.studentId, 's2');
      expect(profiles.first.recommendedAction, isNotEmpty);
    });
  });
}
