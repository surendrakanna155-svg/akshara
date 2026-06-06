import 'package:akshara_erp/features/admissions/approval/admissions_approval_provider.dart';
import 'package:akshara_erp/features/admissions/fee_handoff/admissions_fee_handoff_provider.dart';
import 'package:akshara_erp/features/admissions/reports/admissions_reports_provider.dart';
import 'package:akshara_erp/features/admissions/settings/admissions_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admissionsApprovalProvider', () {
    test('exposes pending approval queue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(admissionsApprovalQueueProvider);
      expect(queue, hasLength(3));
      expect(
        queue.where((item) => item.decision.name == 'pending'),
        hasLength(2),
      );
    });

    test('loads review detail for selected approval', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final review = container.read(admissionsApprovalReviewProvider('appr_1'));
      expect(review, isNotNull);
      expect(review!.counselorNotes, isNotEmpty);
      expect(review.workflowSteps, hasLength(5));
    });
  });

  group('admissionsFeeHandoffProvider', () {
    test('exposes approved students and fee structures', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final handoffs = container.read(admissionsApprovedHandoffsProvider);
      final structures = container.read(admissionsFeeStructuresProvider);

      expect(handoffs, hasLength(3));
      expect(structures, hasLength(3));
      expect(handoffs.first.previewStudentId, startsWith('SIS-STU-'));
    });
  });

  group('admissionsReportsProvider', () {
    test('exposes funnel, source, counselor, and status data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(admissionsReportsProvider);
      expect(data, isNotNull);
      expect(data!.funnelSegments, hasLength(5));
      expect(data.sourceAnalysis, isNotEmpty);
      expect(data.counselorPerformance, isNotEmpty);
      expect(data.applicationStatus, isNotEmpty);
    });
  });

  group('admissionsSettingsProvider', () {
    test('exposes CRM configuration sections', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(admissionsSettingsProvider);
      expect(settings, isNotNull);
      expect(settings!.leadStages, isNotEmpty);
      expect(settings.leadScores, hasLength(3));
      expect(settings.notificationTemplates, hasLength(3));
    });
  });
}
