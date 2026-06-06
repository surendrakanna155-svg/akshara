import 'package:akshara_erp/features/sis/dashboard/sis_dashboard_provider.dart';
import 'package:akshara_erp/features/sis/integration/sis_admissions_integration_provider.dart';
import 'package:akshara_erp/features/sis/integration/sis_finance_integration_provider.dart';
import 'package:akshara_erp/features/sis/profile/sis_profile_provider.dart';
import 'package:akshara_erp/features/sis/registry/sis_registry_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sisDashboardProvider', () {
    test('exposes KPIs and distributions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(sisDashboardProvider);
      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.classDistribution, hasLength(4));
      expect(data.genderDistribution, hasLength(3));
      expect(data.aiInsight, isNotEmpty);
    });

    test('returns null when loading', () {
      final container = ProviderContainer(
        overrides: [
          sisDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(sisDashboardProvider), isNull);
    });
  });

  group('sisStudentsProvider', () {
    test('exposes mock student records', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final students = container.read(sisStudentsProvider);
      expect(students, hasLength(5));
      expect(students.first.id, startsWith('SIS-STU-'));
    });

    test('filters by admission number search', () {
      final container = ProviderContainer(
        overrides: [
          sisRegistrySearchProvider.overrideWith(
            (ref) => 'ADM-2026-0138',
          ),
        ],
      );
      addTearDown(container.dispose);

      final filtered = container.read(sisFilteredStudentsProvider);
      expect(filtered, hasLength(1));
      expect(filtered.first.studentName, 'Arjun Patel');
    });
  });

  group('sisStudentProfileProvider', () {
    test('loads profile with finance fee account', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(
        sisStudentProfileProvider('SIS-STU-10421'),
      );
      expect(profile, isNotNull);
      expect(profile!.feeAccount, isNotNull);
      expect(profile.feeAccount!.feeStructureName, 'Standard CBSE');
    });

    test('returns null for unknown student', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(sisStudentProfileProvider('UNKNOWN')),
        isNull,
      );
    });
  });

  group('sisEnrollmentQueueProvider', () {
    test('includes admissions enrollment records', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(sisEnrollmentQueueProvider);
      expect(queue, hasLength(3));
      expect(queue.first.enrollment.studentName, 'Ananya Reddy');
    });

    test('pending enrollments excludes converted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pending = container.read(sisPendingEnrollmentsProvider);
      expect(pending.length, lessThan(3));
    });
  });

  group('sisFeeAccountForAdmissionProvider', () {
    test('resolves fee account by admission number', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final summary = container.read(
        sisFeeAccountForAdmissionProvider('ADM-2026-0138'),
      );
      expect(summary, isNotNull);
      expect(summary!.balance, '₹1,23,000');
    });
  });
}
