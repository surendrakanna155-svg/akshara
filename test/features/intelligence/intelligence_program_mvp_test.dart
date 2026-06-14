import 'package:akshara_erp/features/evolution/evolution_models.dart';
import 'package:akshara_erp/features/finance/intelligence/fee_collection_intelligence.dart';
import 'package:akshara_erp/features/finance/intelligence/finance_intelligence_models.dart';
import 'package:akshara_erp/features/intelligence/academic/promotion_readiness_intelligence.dart';
import 'package:akshara_erp/features/intelligence/operations/operations_intelligence.dart';
import 'package:akshara_erp/features/intelligence/student_success/at_risk_student_intelligence.dart';
import 'package:akshara_erp/features/intelligence/student_success/attendance_intelligence.dart';
import 'package:akshara_erp/features/intelligence/student_success/student_success_models.dart';
import 'package:akshara_erp/features/intelligence/teacher_effectiveness/teacher_intervention_intelligence.dart';
import 'package:akshara_erp/features/intelligence/unified/unified_recommendation_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('teacher intervention intelligence', () {
    test('classifies high risk students as urgent', () {
      final suggestion = suggestionFromRiskStudent({
        'studentId': 's1',
        'studentName': 'Ravi',
        'className': '8-A',
        'riskLevel': 'high',
        'topReason': 'Weak in algebra',
      });

      expect(suggestion.priority, InterventionPriority.urgent);
      expect(suggestion.suggestedIntervention, contains('remediation'));
    });

    test('buildTeacherInterventionSuggestions filters low priority', () {
      const insights = TeacherAssistantInsights(
        riskStudents: [
          {'studentId': 's1', 'studentName': 'A', 'className': '8-A', 'riskLevel': 'low', 'topReason': 'x'},
          {'studentId': 's2', 'studentName': 'B', 'className': '8-B', 'riskLevel': 'medium', 'topReason': 'y'},
        ],
        weakTopics: ['Fractions'],
        homeworkConcerns: [],
        suggestedActions: ['Review homework'],
        lessonPlanSuggestions: [],
        parentMeetingSummaries: [],
      );

      final suggestions = buildTeacherInterventionSuggestions(insights);
      expect(suggestions, hasLength(1));
      expect(suggestions.first.studentId, 's2');
    });
  });

  group('attendance intelligence', () {
    test('classifies chronic absence below 60%', () {
      expect(classifyAttendanceTier(55), AttendanceRiskTier.chronic);
      expect(classifyAttendanceTier(90), AttendanceRiskTier.stable);
    });

    test('buildAttendanceProfiles filters watch tier and above', () {
      const stable = StudentSuccessSnapshot(
        id: '1',
        studentId: 's1',
        studentName: 'Stable',
        className: '7-A',
        dropoutProbability: 5,
        attendancePrediction: 92,
        performanceDeclineScore: 5,
        improvementScore: 80,
        riskSignals: [],
        predictions: {},
      );
      const watch = StudentSuccessSnapshot(
        id: '2',
        studentId: 's2',
        studentName: 'Watch',
        className: '7-B',
        dropoutProbability: 20,
        attendancePrediction: 80,
        performanceDeclineScore: 10,
        improvementScore: 60,
        riskSignals: [],
        predictions: {},
      );

      final profiles = buildAttendanceProfiles([stable, watch]);
      expect(profiles, hasLength(1));
      expect(profiles.first.tier, AttendanceRiskTier.watch);
    });
  });

  group('fee collection intelligence', () {
    test('classifies critical defaulters', () {
      const prediction = FinanceDefaulterPrediction(
        studentId: 's1',
        studentName: 'Fee',
        className: '9-A',
        outstandingAmount: 12000,
        riskScore: 90,
        daysOverdue: 65,
      );

      expect(classifyFeeCollectionTier(prediction), FeeCollectionRiskTier.critical);
    });

    test('summarizeFeeCollection aggregates outstanding', () {
      const data = FinanceCopilotData(
        feeCollectionForecast: 100000,
        forecastConfidence: 80,
        monthlyRevenueForecast: 90000,
        defaulterPredictions: [
          FinanceDefaulterPrediction(
            studentId: 's1',
            studentName: 'A',
            className: '8-A',
            outstandingAmount: 5000,
            riskScore: 70,
            daysOverdue: 35,
          ),
        ],
        collectionTrend: [
          FinanceCollectionTrendPoint(month: 'Jan', collected: 80000, expected: 100000),
        ],
        riskAlerts: [],
        generatedAt: '2026-06-01',
      );

      final profiles = buildFeeCollectionProfiles(data.defaulterPredictions);
      final summary = summarizeFeeCollection(profiles, data);
      expect(summary.totalOutstanding, 5000);
      expect(summary.collectionGapPercent, 20);
    });
  });

  group('promotion readiness intelligence', () {
    test('holds students with high dropout probability', () {
      const snapshot = StudentSuccessSnapshot(
        id: '1',
        studentId: 's1',
        studentName: 'Hold',
        className: '10-A',
        dropoutProbability: 75,
        attendancePrediction: 80,
        performanceDeclineScore: 40,
        improvementScore: 60,
        riskSignals: [],
        predictions: {},
      );

      final profile = promotionProfileFromSnapshot(snapshot);
      expect(profile.readiness, PromotionReadiness.hold);
    });

    test('promotionReviewQueue excludes ready students', () {
      final profiles = [
        promotionProfileFromSnapshot(
          const StudentSuccessSnapshot(
            id: '1',
            studentId: 's1',
            studentName: 'Ready',
            className: '9-A',
            dropoutProbability: 10,
            attendancePrediction: 95,
            performanceDeclineScore: 5,
            improvementScore: 90,
            riskSignals: [],
            predictions: {},
          ),
        ),
        promotionProfileFromSnapshot(
          const StudentSuccessSnapshot(
            id: '2',
            studentId: 's2',
            studentName: 'Borderline',
            className: '9-B',
            dropoutProbability: 25,
            attendancePrediction: 78,
            performanceDeclineScore: 30,
            improvementScore: 58,
            riskSignals: [],
            predictions: {},
          ),
        ),
      ];

      final queue = promotionReviewQueue(profiles);
      expect(queue, hasLength(1));
      expect(queue.first.readiness, PromotionReadiness.borderline);
    });
  });

  group('operations intelligence', () {
    test('buildSectionBalanceHints detects imbalance', () {
      final snapshots = List.generate(
        20,
        (i) => StudentSuccessSnapshot(
          id: '$i',
          studentId: 's$i',
          studentName: 'S$i',
          className: '8-A',
          sectionName: i < 15 ? 'A' : 'B',
          dropoutProbability: 10,
          attendancePrediction: 90,
          performanceDeclineScore: 5,
          improvementScore: 80,
          riskSignals: [],
          predictions: {},
        ),
      );

      final hints = buildSectionBalanceHints(snapshots);
      expect(hints, isNotEmpty);
      expect(hints.first.kind, OperationsHintKind.sectionBalance);
    });
  });

  group('unified recommendations', () {
    test('aggregates and sorts by priority', () {
      final items = buildUnifiedRecommendations(
        atRisk: const AtRiskIntelligenceSummary(
          totalFlagged: 1,
          criticalCount: 1,
          highCount: 0,
          mediumCount: 0,
          topProfiles: [],
        ),
        feeCollection: FeeCollectionIntelligenceSummary(
          totalFlagged: 1,
          criticalCount: 1,
          highCount: 0,
          totalOutstanding: 1000,
          collectionGapPercent: 10,
          topProfiles: [
            feeProfileFromPrediction(
              const FinanceDefaulterPrediction(
                studentId: 's1',
                studentName: 'Fee',
                className: '8-A',
                outstandingAmount: 1000,
                riskScore: 90,
                daysOverdue: 60,
              ),
            ),
          ],
          alertActions: [],
        ),
      );

      expect(items, isNotEmpty);
      expect(items.first.source, UnifiedRecommendationSource.feeCollection);
    });
  });
}
