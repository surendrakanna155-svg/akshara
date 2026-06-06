import 'package:akshara_erp/features/admissions/applications/admissions_applications_provider.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admissionsDashboardProvider', () {
    test('exposes six KPIs and pipeline stages', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(admissionsDashboardProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.pipeline, hasLength(7));
      expect(data.followUps, isNotEmpty);
      expect(data.aiInsight, isNotEmpty);
    });

    test('returns null when loading', () {
      final container = ProviderContainer(
        overrides: [
          admissionsDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(admissionsDashboardProvider), isNull);
    });
  });

  group('admissionsLeadsProvider', () {
    test('exposes mock lead records', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final leads = container.read(admissionsLeadsProvider);
      expect(leads, hasLength(7));
      expect(leads.first.id, 'LD-1042');
    });

    test('returns empty when empty flag set', () {
      final container = ProviderContainer(
        overrides: [
          admissionsLeadsEmptyProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(admissionsLeadsProvider), isEmpty);
    });
  });

  group('admissionsApplicationsProvider', () {
    test('exposes applications and workflow summary', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final apps = container.read(admissionsApplicationsProvider);
      final workflow = container.read(admissionsApplicationWorkflowProvider);

      expect(apps, hasLength(6));
      expect(workflow.draft, greaterThanOrEqualTo(1));
      expect(workflow.approved, greaterThanOrEqualTo(1));
    });

    test('returns empty when error flag set', () {
      final container = ProviderContainer(
        overrides: [
          admissionsApplicationsErrorProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(admissionsApplicationsProvider), isEmpty);
    });
  });
}
