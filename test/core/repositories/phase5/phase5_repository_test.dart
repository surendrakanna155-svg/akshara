import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/mock/mock_phase5_repositories.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';

void main() {
  const query = RepositoryQuery(tenantId: 'tenant_demo', page: 1, pageSize: 20);

  group('Phase 5 mock repositories', () {
    test('parent experience hub returns integrated sections', () async {
      final repo = MockParentExperienceRepository();
      final hub = await repo.getHub(query: query, studentId: 'student_1');
      expect(hub.overview.childName, isNotEmpty);
      expect(hub.inventory.items, isNotEmpty);
      expect(hub.guidance.available, isTrue);
    });

    test('employee intelligence dashboard returns workload insights', () async {
      final repo = MockEmployeeIntelligenceRepository();
      final dash = await repo.getIntelligenceDashboard(query: query);
      expect(dash.avgWorkloadPercent, greaterThan(0));
      expect(dash.workloadBalancing, isNotEmpty);
    });

    test('operations hub returns school health snapshot', () async {
      final repo = MockOperationsHubRepository();
      final hub = await repo.getHub(query: query);
      expect(hub.schoolHealth, inInclusiveRange(0, 100));
      expect(hub.criticalAlerts, isNotEmpty);
    });

    test('school memories lists published events', () async {
      final repo = MockSchoolMemoriesRepository();
      final events = await repo.listEvents(query: query);
      expect(events, isNotEmpty);
    });

    test('achievement promotion workflow states', () async {
      final repo = MockAchievementPromotionRepository();
      final created = await repo.createPromotion(
        query: query,
        achievementType: 'sports_winner',
        title: 'Inter-school Cricket',
      );
      expect(created.status, 'draft');
      final generated = await repo.generateAssets(query: query, promotionId: created.id);
      expect(generated.status, 'pending_approval');
    });
  });
}
