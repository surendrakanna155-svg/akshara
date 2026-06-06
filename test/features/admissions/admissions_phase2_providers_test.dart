import 'package:akshara_erp/features/admissions/documents/admissions_documents_provider.dart';
import 'package:akshara_erp/features/admissions/enrollment/admissions_enrollment_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_lead_detail_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admissionsLeadDetailProvider', () {
    test('loads full profile for known lead', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(admissionsLeadDetailProvider('LD-1042'));
      expect(profile, isNotNull);
      expect(profile!.lead.studentName, 'Ananya Reddy');
      expect(profile.activities, isNotEmpty);
      expect(profile.followUpHistory, isNotEmpty);
      expect(profile.statusSteps, hasLength(7));
    });

    test('returns null for unknown lead', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(admissionsLeadDetailProvider('LD-UNKNOWN')),
        isNull,
      );
    });

    test('returns null when loading', () {
      final container = ProviderContainer(
        overrides: [
          admissionsLeadDetailLoadingProvider('LD-1042')
              .overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(admissionsLeadDetailProvider('LD-1042')),
        isNull,
      );
    });
  });

  group('admissionsEnrollmentProvider', () {
    test('starts on student profile with mock prefill', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final form = container.read(admissionsEnrollmentProvider);
      expect(form.student.fullName, 'Ananya Reddy');
      expect(form.parent.guardianName, 'Rajesh Reddy');
      expect(form.academic.seekingClass, '5');
    });

    test('advances wizard steps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(admissionsEnrollmentProvider.notifier).nextStep();
      final form = container.read(admissionsEnrollmentProvider);
      expect(form.currentStep.name, 'parentInformation');
    });
  });

  group('admissionsDocumentsProvider', () {
    test('exposes documents and summary KPIs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final docs = container.read(admissionsDocumentsProvider);
      final summary = container.read(admissionsDocumentSummaryProvider);

      expect(docs, hasLength(6));
      expect(summary.missing, greaterThanOrEqualTo(1));
      expect(summary.verified, greaterThanOrEqualTo(1));
    });

    test('builds checklist for lead', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final checklist =
          container.read(admissionsDocumentChecklistProvider('LD-1042'));
      expect(checklist, hasLength(6));
      expect(
        checklist.any((item) => item.documentType.name == 'birthCertificate'),
        isTrue,
      );
    });
  });
}
