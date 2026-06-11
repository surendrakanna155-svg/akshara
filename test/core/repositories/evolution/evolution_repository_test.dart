import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final repo = MockEvolutionRepository();

  test('setup wizard creates session with recommendations', () async {
    final session = await repo.createSetupWizard(
      query: query,
      inputs: {'studentCount': 300, 'teacherCount': 15},
    );
    expect(session.id, isNotEmpty);
    expect(session.warnings, isNotEmpty);
    expect(session.steps.length, greaterThan(5));
  });

  test('dynamic dashboard saves layout reorder', () async {
    final layout = await repo.getDashboardLayout(query: query);
    final reordered = [
      layout.last.copyWith(order: 0),
      ...layout.sublist(0, layout.length - 1),
    ];
    final saved = await repo.saveDashboardLayout(query: query, layout: reordered);
    expect(saved.first.widgetId, layout.last.widgetId);
  });

  test('teacher assistant and principal command return insights', () async {
    final teacher = await repo.getTeacherAssistantInsights(query: query);
    expect(teacher.riskStudents, isNotEmpty);

    final principal = await repo.getPrincipalCommandCenter(query: query);
    expect(principal.topPriorities, isNotEmpty);
  });

  test('parent insights and growth platform workflows', () async {
    final insight = await repo.generateParentInsights(
      query: query,
      studentId: 'student_1',
      period: 'weekly',
    );
    expect(insight.printable, isTrue);

    final campaignId = await repo.createGrowthCampaign(
      query: query,
      name: 'Test Campaign',
      channel: 'referral',
    );
    expect(campaignId, isNotEmpty);

    final dashboard = await repo.getGrowthDashboard(query: query);
    expect(dashboard.activeCampaigns, greaterThan(0));
  });
}
