import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/mock/mock_phase5_repositories.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';

void main() {
  const query = RepositoryQuery(tenantId: 'tenant_demo', page: 1, pageSize: 20);

  group('Phase 5 contract parity (mock)', () {
    test('parent hub includes guidance reports and homework intelligence', () async {
      final repo = MockParentExperienceRepository();
      final hub = await repo.getHub(query: query, studentId: 'student_1');
      expect(hub.guidance.reports.length, greaterThanOrEqualTo(3));
      expect(hub.homeworkIntelligence.weakTopics, isNotEmpty);
    });

    test('promotion assets expose structured metadata previews', () async {
      final repo = MockAchievementPromotionRepository();
      final items = await repo.listPromotions(query: query);
      final published = items.firstWhere((p) => p.status == 'published');
      expect(published.assetPreviews, isNotEmpty);
      expect(published.assetPreviews.first.headline, isNotEmpty);
    });

    test('promotion workflow draft to pending approval', () async {
      final repo = MockAchievementPromotionRepository();
      final created = await repo.createPromotion(
        query: query,
        achievementType: 'gold_medal',
        title: 'Test Medal',
      );
      final generated = await repo.generateAssets(query: query, promotionId: created.id);
      expect(generated.status, 'pending_approval');
    });
  });
}
