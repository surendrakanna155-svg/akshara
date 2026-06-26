import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_enum_codec.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';

/// Builds API-shaped JSON envelopes from domain models for contract tests.
class AdmissionsFixtureBuilder {
  const AdmissionsFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> dashboardEnvelope(AdmissionsDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'aiActionLabel': data.aiActionLabel,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
          },
      ],
      'pipeline': [
        for (final stage in data.pipeline)
          {
            'stage': AdmissionsEnumCodec.leadStageToApi(stage.stage),
            'count': stage.count,
            'leads': [
              for (final lead in stage.leads)
                {
                  'id': lead.id,
                  'studentName': lead.studentName,
                  'classLabel': lead.classLabel,
                  'score': lead.score.name,
                  'source': _leadSource(lead.source),
                  'daysInStage': lead.daysInStage,
                },
            ],
          },
      ],
      'funnelSegments': _segments(data.funnelSegments),
      'sourceSegments': _segments(data.sourceSegments),
      'followUps': [
        for (final fu in data.followUps)
          {
            'id': fu.id,
            'dueLabel': fu.dueLabel,
            'leadName': fu.leadName,
            'task': fu.task,
            'counselor': fu.counselor,
            'priority': fu.priority.name,
            'status': fu.status.name,
          },
      ],
      'leaderboard': [
        for (final entry in data.leaderboard)
          {
            'counselor': entry.counselor,
            'leadsHandled': entry.leadsHandled,
            'conversions': entry.conversions,
            'conversionRate': entry.conversionRate,
          },
      ],
    });
  }

  Map<String, dynamic> leadItem(AdmissionsLead lead) => {
        'id': lead.id,
        'parentName': lead.parentName,
        'studentName': lead.studentName,
        'classLabel': lead.classLabel,
        'phone': lead.phone,
        'source': _leadSource(lead.source),
        'campaign': lead.campaign,
        'stage': AdmissionsEnumCodec.leadStageToApi(lead.stage),
        'counselor': lead.counselor,
        'score': lead.score.name,
        'nextFollowUpLabel': lead.nextFollowUpLabel,
      };

  Map<String, dynamic> applicationItem(AdmissionsApplication app) => {
        'id': app.id,
        'studentName': app.studentName,
        'classLabel': app.classLabel,
        'parentName': app.parentName,
        'submittedLabel': app.submittedLabel,
        'status': _applicationStatus(app.status),
        'documentsComplete': app.documentsComplete,
        'documentsTotal': app.documentsTotal,
        'counselor': app.counselor,
      };

  Map<String, dynamic> documentItem(StudentDocumentRecord doc) => {
        'id': doc.id,
        'studentName': doc.studentName,
        'classLabel': doc.classLabel,
        'documentType': _documentType(doc.documentType),
        'isRequired': doc.isRequired,
        'status': doc.status.name,
        'uploadedLabel': doc.uploadedLabel,
        'verifiedBy': doc.verifiedBy,
        'leadId': doc.leadId,
        'hasFile': doc.hasFile,
      };

  Map<String, dynamic> enrollmentItem(PendingEnrollmentRecord record) => {
        'id': record.id,
        'studentName': record.studentName,
        'applicationId': record.applicationId,
        'seekingClass': record.seekingClass,
        'section': record.section,
        'academicYear': record.academicYear,
        'guardianName': record.guardianName,
        'phone': record.phone,
        'submittedAt': record.submittedAt,
        'conversionStatus': record.conversionStatus.name,
        'generatedAdmissionNumber': record.generatedAdmissionNumber,
        'previewStudentId': record.previewStudentId,
        'gender': record.gender,
        'dateOfBirth': record.dateOfBirth,
      };

  Map<String, dynamic> handoffItem(ApprovedStudentHandoff handoff) => {
        'id': handoff.id,
        'studentName': handoff.studentName,
        'classLabel': handoff.classLabel,
        'applicationId': handoff.applicationId,
        'admissionNumber': handoff.admissionNumber,
        'needsTransport': handoff.needsTransport,
        'needsHostel': handoff.needsHostel,
        'selectedFeeStructureId': handoff.selectedFeeStructureId,
        'handoffStatus': _handoffStatus(handoff.handoffStatus),
        'previewStudentId': handoff.previewStudentId,
        'sisHandoffLabel': handoff.sisHandoffLabel,
      };

  Map<String, dynamic> feeStructureItem(FeeStructureOption option) => {
        'id': option.id,
        'label': option.label,
        'annualAmount': option.annualAmount,
        'installments': option.installments,
      };

  Map<String, dynamic> approvalItem(ApprovalQueueItem item) => {
        'id': item.id,
        'applicationId': item.applicationId,
        'studentName': item.studentName,
        'classLabel': item.classLabel,
        'parentName': item.parentName,
        'counselor': item.counselor,
        'submittedLabel': item.submittedLabel,
        'documentsComplete': item.documentsComplete,
        'documentsTotal': item.documentsTotal,
        'decision': item.decision.name,
        'aiScore': item.aiScore,
      };

  Map<String, dynamic> reportsEnvelope(AdmissionsReportsData data) {
    return envelope({
      'funnelSegments': _segments(data.funnelSegments),
      'sourceAnalysis': [
        for (final row in data.sourceAnalysis)
          {
            'source': _leadSource(row.source),
            'leads': row.leads,
            'converted': row.converted,
            'conversionRate': row.conversionRate,
          },
      ],
      'counselorPerformance': [
        for (final row in data.counselorPerformance)
          {
            'counselor': row.counselor,
            'leads': row.leads,
            'applications': row.applications,
            'approved': row.approved,
            'conversionRate': row.conversionRate,
          },
      ],
      'applicationStatus': [
        for (final row in data.applicationStatus)
          {
            'status': _applicationStatus(row.status),
            'count': row.count,
            'percent': row.percent,
          },
      ],
    });
  }

  Map<String, dynamic> settingsEnvelope(AdmissionsSettingsData data) {
    return envelope({
      'leadStages': [
        for (final stage in data.leadStages)
          {
            'stage': AdmissionsEnumCodec.leadStageToApi(stage.stage),
            'enabled': stage.enabled,
            'autoAdvanceDays': stage.autoAdvanceDays,
          },
      ],
      'leadScores': [
        for (final score in data.leadScores)
          {
            'score': score.score.name,
            'minEngagement': score.minEngagement,
            'followUpHours': score.followUpHours,
          },
      ],
      'workflowSteps': [
        for (final step in data.workflowSteps)
          {
            'status': _applicationStatus(step.status),
            'enabled': step.enabled,
            'requiresPrincipalApproval': step.requiresPrincipalApproval,
          },
      ],
      'assignmentRules': [
        for (final rule in data.assignmentRules)
          {
            'id': rule.id,
            'label': rule.label,
            'strategy': rule.strategy,
            'enabled': rule.enabled,
          },
      ],
      'notificationTemplates': [
        for (final template in data.notificationTemplates)
          {
            'id': template.id,
            'name': template.name,
            'channel': template.channel,
            'preview': template.preview,
            'enabled': template.enabled,
          },
      ],
    });
  }

  Map<String, dynamic> enrollmentPrefillEnvelope(EnrollmentFormState state) {
    return envelope({
      'currentStep': _enrollmentStep(state.currentStep),
      'student': {
        'fullName': state.student.fullName,
        'dateOfBirth': state.student.dateOfBirth,
        'gender': state.student.gender,
        'aadhaar': state.student.aadhaar,
      },
      'parent': {
        'guardianName': state.parent.guardianName,
        'relationship': state.parent.relationship,
        'phone': state.parent.phone,
        'email': state.parent.email,
        'address': state.parent.address,
      },
      'academic': {
        'seekingClass': state.academic.seekingClass,
        'section': state.academic.section,
        'academicYear': state.academic.academicYear,
        'previousSchool': state.academic.previousSchool,
        'needsTransport': state.academic.needsTransport,
        'needsHostel': state.academic.needsHostel,
      },
      'isSubmitting': state.isSubmitting,
      'isSubmitted': state.isSubmitted,
      'generatedAdmissionNumber': state.generatedAdmissionNumber,
    });
  }

  List<Map<String, dynamic>> _segments(List<ChartSegment> segments) {
    return [
      for (final segment in segments)
        {
          'label': segment.label,
          'value': segment.value,
          'percent': segment.percent,
        },
    ];
  }

  String _leadSource(LeadSource source) => switch (source) {
        LeadSource.walkIn => 'walk_in',
        LeadSource.website => 'website',
        LeadSource.referral => 'referral',
        LeadSource.whatsapp => 'whatsapp',
        LeadSource.facebook => 'facebook',
        LeadSource.googleAds => 'google_ads',
      };

  String _applicationStatus(ApplicationStatus status) => switch (status) {
        ApplicationStatus.draft => 'draft',
        ApplicationStatus.submitted => 'submitted',
        ApplicationStatus.documentsPending => 'documents_pending',
        ApplicationStatus.underReview => 'under_review',
        ApplicationStatus.approved => 'approved',
        ApplicationStatus.rejected => 'rejected',
      };

  String _documentType(DocumentType type) => switch (type) {
        DocumentType.birthCertificate => 'birth_certificate',
        DocumentType.aadhaar => 'aadhaar',
        DocumentType.marksMemo => 'marks_memo',
        DocumentType.transferCertificate => 'transfer_certificate',
        DocumentType.photos => 'photos',
        DocumentType.medical => 'medical',
      };

  String _handoffStatus(FeeHandoffStatus status) => switch (status) {
        FeeHandoffStatus.pending => 'pending',
        FeeHandoffStatus.sentToFinance => 'sent_to_finance',
        FeeHandoffStatus.completed => 'completed',
        FeeHandoffStatus.failed => 'failed',
      };

  String _enrollmentStep(EnrollmentStep step) => switch (step) {
        EnrollmentStep.studentProfile => 'student_profile',
        EnrollmentStep.parentInformation => 'parent_information',
        EnrollmentStep.academicInformation => 'academic_information',
        EnrollmentStep.reviewSubmit => 'review_submit',
      };
}
