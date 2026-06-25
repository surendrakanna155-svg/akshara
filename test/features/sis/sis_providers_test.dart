import 'package:akshara_erp/features/admissions/enrollment/admissions_enrollment_records_provider.dart';
import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_provider.dart';
import 'package:akshara_erp/features/sis/dashboard/sis_dashboard_provider.dart';
import 'package:akshara_erp/features/sis/integration/sis_admissions_integration_provider.dart';
import 'package:akshara_erp/features/sis/integration/sis_finance_integration_provider.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_provider.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('sisDashboardProvider', () {
    test('exposes KPIs and distributions', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(sisDashboardFutureProvider.future);

      final data = container.read(sisDashboardProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.classDistribution, hasLength(4));
      expect(data.genderDistribution, hasLength(3));
      expect(data.aiInsight, isNotEmpty);
    });

    test('returns null when loading', () async {
      final container = createProviderTestContainer(
        overrides: [
          sisDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(sisDashboardProvider), isNull);
    });
  });

  group('sisStudentsProvider', () {
    test('exposes mock student records', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(sisStudentsFutureProvider.future);

      final students = container.read(sisStudentsProvider);
      // 10 real students + 1 generated placeholder (isPlaceholder) seeded to
      // exercise the first-time-onboarding placeholder UI in the registry.
      expect(students, hasLength(11));
      expect(students.first.id, startsWith('SIS-STU-'));
    });

    test('filters by admission number search', () async {
      final container = createProviderTestContainer(
        overrides: [
          sisRegistrySearchProvider.overrideWith(
            (ref) => 'ADM-2026-0138',
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sisStudentsFutureProvider.future);

      final filtered = container.read(sisFilteredStudentsProvider);
      expect(filtered, hasLength(1));
      expect(filtered.first.studentName, 'Arjun Patel');
    });
  });

  group('sisStudentProfileProvider', () {
    test('loads profile with finance fee account', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(sisStudentsFutureProvider.future);
      await container.read(financeStudentAccountsFutureProvider.future);

      final profile = container.read(
        sisStudentProfileProvider('SIS-STU-10421'),
      );
      expect(profile, isNotNull);
      expect(profile!.feeAccount, isNotNull);
      expect(profile.feeAccount!.feeStructureName, 'Standard CBSE');
    });

    test('returns null for unknown student', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      expect(
        container.read(sisStudentProfileProvider('UNKNOWN')),
        isNull,
      );
    });
  });

  group('sisEnrollmentQueueProvider', () {
    test('includes admissions enrollment records', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsPendingEnrollmentsFutureProvider.future);

      final queue = container.read(sisEnrollmentQueueProvider);
      expect(queue, hasLength(3));
      expect(queue.first.enrollment.studentName, 'Ananya Reddy');
    });

    test('pending enrollments excludes converted', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsPendingEnrollmentsFutureProvider.future);

      final pending = container.read(sisPendingEnrollmentsProvider);
      expect(pending.length, lessThan(3));
    });
  });

  group('sisFeeAccountForAdmissionProvider', () {
    test('resolves fee account by admission number', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(financeStudentAccountsFutureProvider.future);

      final summary = container.read(
        sisFeeAccountForAdmissionProvider('ADM-2026-0138'),
      );
      expect(summary, isNotNull);
      expect(summary!.balance, '₹1,23,000');
    });
  });
}
