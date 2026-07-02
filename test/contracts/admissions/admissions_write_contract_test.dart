import 'package:akshara_erp/core/repositories/api/admissions/dto/application_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/assign_counselor_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/create_lead_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/enrollment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/finance_handoff_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/followup_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/lead_action_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/save_admissions_settings_request_dto.dart';
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

    test('bulk lead action (assign) serializes leadIds + counselor', () {
      final json = BulkLeadActionRequestDto.fromDomain(
        const BulkLeadActionRequest.assign(
          leadIds: ['LD-1', 'LD-2'],
          counselor: 'Meera N.',
        ),
      ).toJson();
      expect(json['leadIds'], ['LD-1', 'LD-2']);
      expect(json['action'], 'assign');
      expect(json['counselor'], 'Meera N.');
      expect(json.containsKey('stage'), isFalse);
    });

    test('bulk lead action (stage) serializes snake_case stage code', () {
      final json = BulkLeadActionRequestDto.fromDomain(
        const BulkLeadActionRequest.stage(
          leadIds: ['LD-1'],
          stage: LeadStage.schoolVisit,
        ),
      ).toJson();
      expect(json['action'], 'stage');
      expect(json['stage'], 'school_visit');
      expect(json.containsKey('counselor'), isFalse);
    });

    test('mark lead lost request serializes fixed-picklist reason code', () {
      final json = MarkLeadLostRequestDto.fromDomain(
        const MarkLeadLostRequest(reason: LeadLostReason.feesHigh),
      ).toJson();
      expect(json['reason'], 'fees_high');
    });

    test('complete follow-up request omits empty outcome', () {
      expect(
        CompleteFollowUpRequestDto.fromDomain(
          const CompleteFollowUpRequest(),
        ).toJson(),
        isEmpty,
      );
      expect(
        CompleteFollowUpRequestDto.fromDomain(
          const CompleteFollowUpRequest(outcome: 'Parent confirmed'),
        ).toJson()['outcome'],
        'Parent confirmed',
      );
    });

    test('reschedule follow-up request uses scheduled_label key', () {
      final json = RescheduleFollowUpRequestDto.fromDomain(
        const RescheduleFollowUpRequest(scheduledLabel: 'Next Mon 9 AM'),
      ).toJson();
      expect(json['scheduled_label'], 'Next Mon 9 AM');
    });

    test('save settings request serializes the full snapshot shape', () {
      const settings = AdmissionsSettingsData(
        leadStages: [
          LeadStageConfig(
            stage: LeadStage.newEnquiry,
            enabled: true,
            autoAdvanceDays: 3,
          ),
        ],
        leadScores: [
          LeadScoreConfig(
            score: LeadScore.hot,
            minEngagement: 80,
            followUpHours: 4,
          ),
        ],
        workflowSteps: [
          ApplicationWorkflowConfig(
            status: ApplicationStatus.underReview,
            enabled: true,
            requiresPrincipalApproval: true,
          ),
        ],
        assignmentRules: [
          CounselorAssignmentRule(
            id: 'rule_1',
            label: 'Round-robin',
            strategy: 'round_robin',
            enabled: true,
          ),
        ],
        notificationTemplates: [
          NotificationTemplate(
            id: 'tpl_1',
            name: 'Visit reminder',
            channel: 'WhatsApp',
            preview: 'Reminder',
            enabled: true,
          ),
        ],
      );
      final json =
          SaveAdmissionsSettingsRequestDto.fromDomain(settings).toJson();
      final stages = json['leadStages'] as List<dynamic>;
      expect((stages.first as Map)['stage'], 'new_enquiry');
      final steps = json['workflowSteps'] as List<dynamic>;
      expect((steps.first as Map)['status'], 'under_review');
      expect((steps.first as Map)['requiresPrincipalApproval'], isTrue);
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

    test('bulkLeadAction assign updates found leads, skips missing', () async {
      final leads = await repo.getLeads(query: kQuery);
      final id = leads.items.first.id;
      final result = await repo.bulkLeadAction(
        query: kQuery,
        request: BulkLeadActionRequest.assign(
          leadIds: [id, 'LD-DOES-NOT-EXIST'],
          counselor: 'Priya Sharma',
        ),
      );
      expect(result.updated, contains(id));
      expect(result.skipped.map((s) => s.leadId),
          contains('LD-DOES-NOT-EXIST'));
      expect(result.skipped.first.reason, 'not_found');
      final after = await repo.getLeads(query: kQuery);
      expect(
        after.items.firstWhere((l) => l.id == id).counselor,
        'Priya Sharma',
      );
    });

    test('bulkLeadAction stage moves found leads', () async {
      final leads = await repo.getLeads(query: kQuery);
      final id = leads.items.first.id;
      final result = await repo.bulkLeadAction(
        query: kQuery,
        request: BulkLeadActionRequest.stage(
          leadIds: [id],
          stage: LeadStage.joined,
        ),
      );
      expect(result.updated, [id]);
      final after = await repo.getLeads(query: kQuery);
      expect(after.items.firstWhere((l) => l.id == id).stage, LeadStage.joined);
    });

    test('markLeadLost moves the lead to the lost stage', () async {
      final leads = await repo.getLeads(query: kQuery);
      final id = leads.items.first.id;
      final updated = await repo.markLeadLost(
        query: kQuery,
        leadId: id,
        request: const MarkLeadLostRequest(reason: LeadLostReason.competitor),
      );
      expect(updated.stage, LeadStage.lost);
    });

    test('completeFollowUp returns a completed record', () async {
      final leads = await repo.getLeads(query: kQuery);
      final record = await repo.completeFollowUp(
        query: kQuery,
        leadId: leads.items.first.id,
        followUpId: 'fh_1',
        request: const CompleteFollowUpRequest(outcome: 'Confirmed'),
      );
      expect(record.status, FollowUpStatus.completed);
      expect(record.outcome, 'Confirmed');
    });

    test('rescheduleFollowUp returns a pending record with the new label',
        () async {
      final leads = await repo.getLeads(query: kQuery);
      final record = await repo.rescheduleFollowUp(
        query: kQuery,
        leadId: leads.items.first.id,
        followUpId: 'fh_1',
        request: const RescheduleFollowUpRequest(scheduledLabel: 'Fri 3 PM'),
      );
      expect(record.status, FollowUpStatus.pending);
      expect(record.scheduledLabel, 'Fri 3 PM');
    });

    test('checkDuplicateByPhone finds a lead sharing the phone', () async {
      final leads = await repo.getLeads(query: kQuery);
      final existing = leads.items.first;
      final result = await repo.checkDuplicateByPhone(
        query: kQuery,
        phone: existing.phone,
      );
      expect(result.hasDuplicate, isTrue);
      expect(result.matches.map((m) => m.leadId), contains(existing.id));
    });

    test('checkDuplicateByPhone returns no match for an unknown phone',
        () async {
      final result = await repo.checkDuplicateByPhone(
        query: kQuery,
        phone: '+91 00000 00000',
      );
      expect(result.hasDuplicate, isFalse);
      expect(result.matches, isEmpty);
    });

    test('saveSettings persists the full snapshot for getSettings', () async {
      final current = await repo.getSettings(query: kQuery);
      final flipped = AdmissionsSettingsData(
        leadStages: [
          for (final stage in current.leadStages)
            LeadStageConfig(
              stage: stage.stage,
              enabled: !stage.enabled,
              autoAdvanceDays: stage.autoAdvanceDays,
            ),
        ],
        leadScores: current.leadScores,
        workflowSteps: current.workflowSteps,
        assignmentRules: current.assignmentRules,
        notificationTemplates: current.notificationTemplates,
      );
      final saved = await repo.saveSettings(
        query: kQuery,
        request: SaveAdmissionsSettingsRequest(settings: flipped),
      );
      final reloaded = await repo.getSettings(query: kQuery);
      expect(
        saved.leadStages.first.enabled,
        !current.leadStages.first.enabled,
      );
      expect(
        reloaded.leadStages.first.enabled,
        !current.leadStages.first.enabled,
      );
    });

    test('getOfferLetter returns letter data for a handoff enrollment',
        () async {
      final handoffs = await repo.getApprovedHandoffs(query: kQuery);
      final withEnrollment = handoffs.items.firstWhere(
        (h) => h.enrollmentId != null,
      );
      final letter = await repo.getOfferLetter(
        query: kQuery,
        enrollmentId: withEnrollment.enrollmentId!,
      );
      expect(letter.enrollmentId, withEnrollment.enrollmentId);
      expect(letter.admissionNumber, isNotEmpty);
    });
  });
}
