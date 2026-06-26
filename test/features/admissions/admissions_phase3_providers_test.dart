import 'package:akshara_erp/features/admissions/approval/admissions_approval_provider.dart';
import 'package:akshara_erp/features/admissions/fee_handoff/admissions_fee_handoff_provider.dart';
import 'package:akshara_erp/features/admissions/reports/admissions_reports_provider.dart';
import 'package:akshara_erp/features/admissions/settings/admissions_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('admissionsApprovalProvider', () {
    test('exposes pending approval queue', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsApprovalQueueFutureProvider.future);

      final queue = container.read(admissionsApprovalQueueProvider);
      expect(queue, hasLength(3));
      expect(
        queue.where((item) => item.decision.name == 'pending'),
        hasLength(2),
      );
    });

    test('loads review detail for selected approval', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsApprovalQueueFutureProvider.future);

      final review = container.read(admissionsApprovalReviewProvider('appr_1'));
      expect(review, isNotNull);
      // MJ-H15: the review detail is now built from the REAL approval-queue row.
      // The factual workflow stages remain; the previously fabricated counselor
      // notes are gone (honest empty until a real note is persisted via
      // POST /admissions/approval/{id}/notes), and the history is derived from
      // the row's real submission/decision — never invented.
      expect(review!.workflowSteps, hasLength(5));
      expect(review.counselorNotes, isEmpty);
      expect(review.history, isNotEmpty);
    });
  });

  group('admissionsFeeHandoffProvider', () {
    test('exposes approved students and fee structures', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsApprovedHandoffsRawFutureProvider.future);
      await container.read(admissionsFeeStructuresFutureProvider.future);

      final handoffs = container.read(admissionsApprovedHandoffsProvider);
      final structures = container.read(admissionsFeeStructuresProvider);

      expect(handoffs, hasLength(3));
      expect(structures, hasLength(3));
      expect(handoffs.first.previewStudentId, startsWith('SIS-STU-'));
    });
  });

  group('admissionsReportsProvider', () {
    test('exposes funnel, source, counselor, and status data', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsReportsFutureProvider.future);

      final data = container.read(admissionsReportsProvider);
      expect(data, isNotNull);
      expect(data!.funnelSegments, hasLength(5));
      expect(data.sourceAnalysis, isNotEmpty);
      expect(data.counselorPerformance, isNotEmpty);
      expect(data.applicationStatus, isNotEmpty);
    });
  });

  group('admissionsSettingsProvider', () {
    test('exposes CRM configuration sections', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsSettingsFutureProvider.future);

      final settings = container.read(admissionsSettingsProvider);
      expect(settings, isNotNull);
      expect(settings!.leadStages, isNotEmpty);
      expect(settings.leadScores, hasLength(3));
      expect(settings.notificationTemplates, hasLength(3));
    });
  });
}
