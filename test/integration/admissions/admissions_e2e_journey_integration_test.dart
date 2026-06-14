import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_sis_bridge.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_write_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock-layer admission → SIS journey chain (linked by applicationId).
void main() {
  group('Admissions E2E journey (mock repositories)', () {
    const query = RepositoryQuery.demo;
    late MockAdmissionsRepository admissions;
    late MockSisRepository sis;

    setUp(() {
      admissions = MockAdmissionsRepository();
      sis = MockSisRepository();
      final store = MockAdmissionsWriteStore.instance;
      store.leads = null;
      store.applications = null;
      store.enrollments = null;
      store.approvalQueue = null;
      store.handoffs = null;
      store.applicationLeadIds.clear();
      final sisStore = MockSisWriteStore.instance;
      sisStore.students = null;
      sisStore.conversionQueue = null;
    });

    test('linked record chain through conversion', () async {
      const studentName = 'Journey Test Student';
      const parentName = 'Journey Test Parent';

      final lead = await admissions.createLead(
        query: query,
        request: const CreateLeadRequest(
          parentName: parentName,
          studentName: studentName,
          classLabel: '5',
          phone: '9876500001',
        ),
      );

      final app = await admissions.createApplication(
        query: query,
        request: CreateApplicationRequest(
          studentName: studentName,
          classLabel: '5',
          parentName: parentName,
          leadId: lead.id,
        ),
      );
      expect(MockAdmissionsWriteStore.instance.applicationLeadIds[app.id], lead.id);

      await admissions.submitApplication(query: query, applicationId: app.id);

      final enrollment = await admissions.submitEnrollment(
        query: query,
        request: EnrollmentSubmitRequest(
          student: const EnrollmentStudentProfile(fullName: studentName),
          parent: const EnrollmentParentInfo(
            guardianName: parentName,
            relationship: 'Father',
            phone: '9876500001',
          ),
          academic: const EnrollmentAcademicInfo(
            seekingClass: '5',
            section: 'A',
            academicYear: '2026–27',
          ),
          applicationId: app.id,
        ),
      );
      expect(enrollment.applicationId, app.id);

      final approval = MockAdmissionsWriteStore.instance.findApprovalByApplication(
        app.id,
      );
      expect(approval, isNotNull);
      expect(approval!.decision, ApprovalDecision.pending);
      expect(approval.studentName, studentName);

      final approved = await admissions.approveAdmission(
        query: query,
        approvalId: approval.id,
        request: const ApprovalDecisionRequest(comment: 'Approved for E2E'),
      );
      expect(approved.decision, ApprovalDecision.approved);
      expect(
        MockAdmissionsSisBridge.isApplicationApproved(app.id),
        isTrue,
      );

      final studentsBefore = await sis.getStudents(query: query);
      final countBefore = studentsBefore.total;

      final conversion = await sis.convertAdmissionsEnrollment(
        query: query,
        request: AdmissionsConversionRequest(
          enrollmentId: enrollment.id,
          classLabel: '5',
          section: 'A',
          academicYear: '2026–27',
        ),
      );
      expect(conversion.studentName, studentName);
      expect(conversion.admissionNumber, isNotEmpty);

      final studentsAfter = await sis.getStudents(query: query);
      expect(studentsAfter.total, greaterThan(countBefore));
      expect(
        studentsAfter.items.any((s) => s.studentName == studentName),
        isTrue,
      );

      final handoffs = await admissions.getApprovedHandoffs(query: query);
      expect(
        handoffs.items.any((h) => h.applicationId == app.id),
        isTrue,
      );
    });
  });
}
