import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/mock/mock_phase5_repositories.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';

void main() {
  group('parent dashboard child-aware', () {
    test('forActiveChild updates greeting and summary for sibling', () {
      final base = ParentDashboardData.mock();
      final priya = base.forActiveChild(childName: 'Priya Kumar', childClass: '5-B');
      expect(priya.childName, 'Priya Kumar');
      expect(priya.greetingHeadline, "Priya's Day at a Glance");
      expect(priya.todaySummary.length, 2);
    });
  });

  group('school memories repository', () {
    const query = RepositoryQuery.demo;

    test('upload flow creates media with share token', () async {
      final repo = MockSchoolMemoriesRepository();
      final confirm = await repo.uploadMediaBytes(
        query: query,
        eventId: 'evt_1',
        bytes: [0xFF, 0xD8, 0xFF],
        filename: 'test.jpg',
        title: 'Test upload',
      );
      expect(confirm.shareToken, isNotEmpty);
      final event = await repo.getEvent(query: query, eventId: 'evt_1');
      expect(event.albums.any((a) => a.media.isNotEmpty), isTrue);
    });

    test('resolve share link returns download url', () async {
      final repo = MockSchoolMemoriesRepository();
      final link = await repo.resolveShareLink(query: query, shareToken: 'share_demo_1');
      expect(link.downloadUrl, isNotEmpty);
    });
  });

  group('parent experience per student', () {
    const query = RepositoryQuery.demo;

    test('student_2 hub differs from student_1', () async {
      final repo = MockParentExperienceRepository();
      final ravi = await repo.getHub(query: query, studentId: 'student_1');
      final priya = await repo.getHub(query: query, studentId: 'student_2');
      expect(ravi.overview.childName, isNot(equals(priya.overview.childName)));
      expect(priya.overview.pendingPaymentRequests, 1);
      expect(ravi.overview.pendingInventoryAcks, 1);
    });
  });
}
