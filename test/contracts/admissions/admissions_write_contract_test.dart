import 'package:akshara_erp/core/repositories/api/admissions/dto/application_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/assign_counselor_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/create_lead_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/enrollment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/finance_handoff_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/followup_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/update_admissions_settings_request_dto.dart';
import 'package:akshara_erp/core/repositories/interfaces/admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Admissions write DTO serialization', () {
    test('create lead request uses snake_case keys', () {
      const request = CreateLeadRequest(
        parentName: 'Rajesh',
        studentName: 'Ananya',
        classLabel: '5',
        phone: '9876543210',
        source: LeadSource.walkIn,
      );
      final json = CreateLeadRequestDto.fromDomain(request).toJson();
      expect(json['parent_name'], 'Rajesh');
      expect(json['student_name'], 'Ananya');
      expect(json['source'], 'walk_in');
    });

    test('assign counselor request serializes counselor', () {
      final json = AssignCounselorRequestDto.fromDomain(
        const AssignCounselorRequest(counselor: 'Priya Sharma'),
      ).toJson();
      expect(json['counselor'], 'Priya Sharma');
    });

    test('application request create payload includes lead id', () {
      final json = ApplicationRequestDto.create(
        const CreateApplicationRequest(
          studentName: 'Ravi',
          classLabel: '8',
          parentName: 'Suresh',
          leadId: 'LD-1042',
        ),
      ).toJson();
      expect(json['lead_id'], 'LD-1042');
    });

    test('enrollment submit payload nests student and parent blocks', () {
      final json = EnrollmentRequestDto.submit(
        const EnrollmentSubmitRequest(
          student: EnrollmentStudentProfile(fullName: 'Ravi Kumar'),
          parent: EnrollmentParentInfo(guardianName: 'Suresh Kumar'),
          academic: EnrollmentAcademicInfo(seekingClass: '8'),
        ),
      ).toJson();
      expect((json['student'] as Map)['full_name'], 'Ravi Kumar');
      expect((json['parent'] as Map)['guardian_name'], 'Suresh Kumar');
    });

    test('finance handoff send payload includes fee structure id', () {
      final json = FinanceHandoffRequestDto.send(
        const FinanceHandoffRequest(
          handoffId: 'HO-1',
          feeStructureId: 'FS-1',
        ),
      ).toJson();
      expect(json['handoff_id'], 'HO-1');
      expect(json['fee_structure_id'], 'FS-1');
    });

    test('follow-up request serializes scheduled label', () {
      final json = FollowUpRequestDto.fromDomain(
        const FollowUpRequest(
          task: 'Call parent',
          scheduledLabel: 'Tomorrow 10 AM',
        ),
      ).toJson();
      expect(json['task'], 'Call parent');
      expect(json['scheduled_label'], 'Tomorrow 10 AM');
    });

    test('update settings request uses snake_case keys', () {
      final json = UpdateAdmissionsSettingsRequestDto.fromDomain(
        const UpdateAdmissionsSettingsRequest(
          academicYear: '2026-27',
          updates: [
            AdmissionsSettingUpdate(
              sectionId: 'leadStages',
              itemId: 'newEnquiry.enabled',
              value: 'false',
            ),
          ],
        ),
      ).toJson();
      expect(json['academic_year'], '2026-27');
      final updates = json['updates'] as List<dynamic>;
      expect(
          (updates.first as Map<String, dynamic>)['section_id'], 'leadStages');
      expect((updates.first)['item_id'], 'newEnquiry.enabled');
    });
  });

  group('Mock admissions write repository', () {
    late MockAdmissionsRepository repo;

    setUp(() {
      repo = MockAdmissionsRepository();
    });

    test('implements all write methods on AdmissionsRepository', () {
      expect(repo, isA<AdmissionsRepository>());
    });

    test('createLead returns persisted lead in subsequent getLeads', () async {
      final created = await repo.createLead(
        query: kQuery,
        request: const CreateLeadRequest(
          parentName: 'Test Parent',
          studentName: 'Test Student',
          classLabel: '6',
          phone: '9000000000',
        ),
      );
      final leads = await repo.getLeads(query: kQuery);
      expect(leads.items.any((lead) => lead.id == created.id), isTrue);
    });

    test('submitApplication moves application to submitted status', () async {
      final apps = await repo.getApplications(query: kQuery);
      final draft =
          apps.items.firstWhere((a) => a.status == ApplicationStatus.draft);
      final submitted = await repo.submitApplication(
        query: kQuery,
        applicationId: draft.id,
      );
      expect(submitted.status, ApplicationStatus.submitted);
    });

    test('approveDocument marks document verified', () async {
      final docs = await repo.getDocuments(query: kQuery);
      final pending = docs.items.firstWhere(
        (doc) => doc.status == DocumentVerificationStatus.uploaded,
      );
      final approved = await repo.approveDocument(
        query: kQuery,
        documentId: pending.id,
        request: const DocumentVerificationRequest(note: 'OK'),
      );
      expect(approved.status, DocumentVerificationStatus.verified);
    });

    test('updateSettings persists values in subsequent getSettings', () async {
      final updated = await repo.updateSettings(
        query: kQuery,
        request: const UpdateAdmissionsSettingsRequest(
          updates: [
            AdmissionsSettingUpdate(
              sectionId: 'leadStages',
              itemId: 'newEnquiry.enabled',
              value: 'false',
            ),
          ],
        ),
      );
      final persisted = await repo.getSettings(query: kQuery);
      final updatedStage = updated.leadStages.firstWhere(
        (stage) => stage.stage == LeadStage.newEnquiry,
      );
      final persistedStage = persisted.leadStages.firstWhere(
        (stage) => stage.stage == LeadStage.newEnquiry,
      );
      expect(updatedStage.enabled, isFalse);
      expect(persistedStage.enabled, isFalse);
    });
  });
}
