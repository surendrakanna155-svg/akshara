import 'package:akshara_erp/features/admissions/applications/admissions_applications_provider.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('admissionsDashboardProvider', () {
    test('exposes six KPIs and pipeline stages', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsDashboardFutureProvider.future);

      final data = container.read(admissionsDashboardProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.pipeline, hasLength(7));
      expect(data.followUps, isNotEmpty);
      expect(data.aiInsight, isNotEmpty);
    });

    test('returns null when loading', () async {
      final container = createProviderTestContainer(
        overrides: [
          admissionsDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      await container.read(admissionsDashboardFutureProvider.future);

      expect(container.read(admissionsDashboardProvider), isNull);
    });
  });

  group('admissionsLeadsProvider', () {
    test('exposes mock lead records', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsLeadsFutureProvider.future);

      final leads = container.read(admissionsLeadsProvider);
      expect(leads, hasLength(7));
      expect(leads.first.id, 'LD-1042');
    });

    test('returns empty when empty flag set', () async {
      final container = createProviderTestContainer(
        overrides: [
          admissionsLeadsEmptyProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      await container.read(admissionsLeadsFutureProvider.future);

      expect(container.read(admissionsLeadsProvider), isEmpty);
    });
  });

  group('admissionsApplicationsProvider', () {
    test('exposes applications and workflow summary', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsApplicationsFutureProvider.future);

      final apps = container.read(admissionsApplicationsProvider);
      final workflow = container.read(admissionsApplicationWorkflowProvider);

      expect(apps, hasLength(6));
      expect(workflow.draft, greaterThanOrEqualTo(1));
      expect(workflow.approved, greaterThanOrEqualTo(1));
    });

    test('returns empty when error flag set', () async {
      final container = createProviderTestContainer(
        overrides: [
          admissionsApplicationsErrorProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      await container.read(admissionsApplicationsFutureProvider.future);

      expect(container.read(admissionsApplicationsProvider), isEmpty);
    });
  });
}
