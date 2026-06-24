import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/documents/admissions_documents_provider.dart';
import 'package:akshara_erp/features/admissions/enrollment/admissions_enrollment_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_lead_detail_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('admissionsLeadDetailProvider', () {
    test('loads full profile for known lead', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsLeadsFutureProvider.future);
      await container.read(admissionsLeadDetailDataProvider('LD-1042').future);

      final profile = container.read(admissionsLeadDetailProvider('LD-1042'));
      expect(profile, isNotNull);
      expect(profile!.lead.studentName, 'Ananya Reddy');
      expect(profile.activities, isNotEmpty);
      expect(profile.followUpHistory, isNotEmpty);
      expect(profile.statusSteps, hasLength(7));
    });

    test('returns null for unknown lead', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      expect(
        container.read(admissionsLeadDetailProvider('LD-UNKNOWN')),
        isNull,
      );
    });

    test('returns null when loading', () async {
      final container = createProviderTestContainer(
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
    test('starts on student profile with mock prefill', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsEnrollmentPrefillFutureProvider.future);

      final form = container.read(admissionsEnrollmentProvider);
      expect(form.student.fullName, 'Ananya Reddy');
      expect(form.parent.guardianName, 'Rajesh Reddy');
      expect(form.academic.seekingClass, '5');
    });

    test('advances wizard steps when student step is valid', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(admissionsEnrollmentProvider.notifier);
      notifier.updateStudent(
        const EnrollmentStudentProfile(
          fullName: 'Ravi Kumar',
          dateOfBirth: '01 Jan 2012',
          gender: 'Male',
          aadhaar: '123456789012',
        ),
      );
      expect(notifier.nextStep(), isTrue);
      final form = container.read(admissionsEnrollmentProvider);
      expect(form.currentStep.name, 'parentInformation');
    });

    test('blocks wizard advance when student step is invalid', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(admissionsEnrollmentProvider.notifier);
      expect(notifier.nextStep(), isFalse);
      expect(
        container.read(admissionsEnrollmentProvider).currentStep.name,
        'studentProfile',
      );
    });
  });

  group('admissionsDocumentsProvider', () {
    test('exposes documents and summary KPIs', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsDocumentsFutureProvider.future);

      final docs = container.read(admissionsDocumentsProvider);
      final summary = container.read(admissionsDocumentSummaryProvider);

      expect(docs, hasLength(6));
      expect(summary.missing, greaterThanOrEqualTo(1));
      expect(summary.verified, greaterThanOrEqualTo(1));
    });

    test('builds checklist for lead', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);
      await container.read(admissionsDocumentsFutureProvider.future);

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
