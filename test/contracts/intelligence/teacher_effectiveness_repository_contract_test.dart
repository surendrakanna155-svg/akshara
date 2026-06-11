import 'package:akshara_erp/core/repositories/mock/mock_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockIntelligenceRepository();

  group('Teacher effectiveness contract parity', () {
    test('lesson effectiveness scores return scored lessons', () async {
      final scores = await repo.getLessonEffectivenessScores(query: query);
      expect(scores, isNotEmpty);
      expect(scores.first.effectivenessScore, greaterThan(0));
    });

    test('topic mastery analytics returns mastery entries', () async {
      final mastery = await repo.getTopicMasteryAnalytics(query: query);
      expect(mastery.length, greaterThanOrEqualTo(2));
      expect(mastery.first.masteryPercent, greaterThanOrEqualTo(0));
    });

    test('teacher performance insights returns strengths and improvements', () async {
      final insights = await repo.getTeacherPerformanceInsights(query: query);
      expect(insights.overallEffectivenessScore, greaterThan(0));
      expect(insights.strengths, isNotEmpty);
    });

    test('teacher planning center returns actionable items', () async {
      final planning = await repo.getTeacherPlanningCenter(query: query);
      expect(planning.weeklyFocus, isNotEmpty);
      expect(planning.planningItems, isNotEmpty);
    });

    test('parent meeting summary generator returns structured printable summary', () async {
      final summary = await repo.generateParentMeetingSummary(
        query: query,
        studentId: 'student_1',
        studentName: 'Arjun Reddy',
        className: 'Grade 8',
        meetingDate: '2026-06-20',
        attendancePercent: 62,
        recentMarks: 54,
      );
      expect(summary.printable, isTrue);
      expect(summary.summary.opening, contains('Arjun Reddy'));
      expect(summary.summary.actionItems, isNotEmpty);
    });
  });
}
