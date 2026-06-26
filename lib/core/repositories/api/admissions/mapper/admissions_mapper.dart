import 'package:flutter/material.dart';

import '../dto/admissions_applications_dto.dart';
import '../dto/admissions_approval_dto.dart';
import '../dto/admissions_dashboard_dto.dart';
import '../dto/admissions_documents_dto.dart';
import '../dto/admissions_enrollments_dto.dart';
import '../dto/admissions_handoffs_dto.dart';
import '../dto/admissions_intelligence_dto.dart';
import '../dto/admissions_leads_dto.dart';
import '../dto/admissions_reports_dto.dart';
import '../dto/admissions_settings_dto.dart';
import '../dto/admissions_enum_codec.dart';
import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/admissions/admissions_requests.dart';

/// Maps Admissions API DTOs to domain models.
class AdmissionsMapper {
  const AdmissionsMapper();

  AdmissionsDashboardData toDashboard(AdmissionsDashboardDto dto) {
    final raw = dto.raw;
    return AdmissionsDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      pipeline: _mapPipeline(raw['pipeline'] as List<dynamic>? ?? const []),
      funnelSegments:
          _mapChartSegments(raw['funnelSegments'] as List<dynamic>? ?? const []),
      sourceSegments:
          _mapChartSegments(raw['sourceSegments'] as List<dynamic>? ?? const []),
      followUps: _mapFollowUps(raw['followUps'] as List<dynamic>? ?? const []),
      leaderboard:
          _mapLeaderboard(raw['leaderboard'] as List<dynamic>? ?? const []),
      aiInsight: raw['aiInsight'] as String? ?? '',
      aiActionLabel: raw['aiActionLabel'] as String? ?? '',
    );
  }

  AdmissionsIntelligenceData toIntelligence(AdmissionsIntelligenceDto dto) {
    final raw = dto.raw;
    final funnelRaw = raw['funnel'] as Map<String, dynamic>? ?? const {};
    final topSourceRaw = funnelRaw['topSource'] as Map<String, dynamic>?;
    final stageCountsRaw =
        funnelRaw['stageCounts'] as Map<String, dynamic>? ?? const {};
    final funnel = AdmissionsFunnelSummary(
      totalLeads: (funnelRaw['totalLeads'] as num?)?.toInt() ?? 0,
      hotLeads: (funnelRaw['hotLeads'] as num?)?.toInt() ?? 0,
      conversionRate: (funnelRaw['conversionRate'] as num?)?.toDouble() ?? 0,
      pendingFollowUps: (funnelRaw['pendingFollowUps'] as num?)?.toInt() ?? 0,
      unassignedLeads: (funnelRaw['unassignedLeads'] as num?)?.toInt() ?? 0,
      stageCounts: {
        for (final entry in stageCountsRaw.entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      },
      topSource: topSourceRaw?['source'] as String?,
      topSourceCount: (topSourceRaw?['count'] as num?)?.toInt() ?? 0,
    );
    final actions = (raw['nextBestActions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_toNextBestAction)
        .toList(growable: false);
    return AdmissionsIntelligenceData(
      funnel: funnel,
      nextBestActions: actions,
    );
  }

  AdmissionsNextBestAction _toNextBestAction(Map<String, dynamic> raw) {
    return AdmissionsNextBestAction(
      id: raw['id'] as String? ?? '',
      kind: raw['kind'] as String? ?? '',
      priority: _parseActionPriority(raw['priority'] as String?),
      title: raw['title'] as String? ?? '',
      detail: raw['detail'] as String? ?? '',
      cta: raw['cta'] as String? ?? '',
      count: (raw['count'] as num?)?.toInt(),
      leadId: raw['leadId'] as String?,
    );
  }

  AdmissionsActionPriority _parseActionPriority(String? value) {
    switch (value) {
      case 'urgent':
        return AdmissionsActionPriority.urgent;
      case 'high':
        return AdmissionsActionPriority.high;
      case 'low':
        return AdmissionsActionPriority.low;
      case 'medium':
      default:
        return AdmissionsActionPriority.medium;
    }
  }

  List<AdmissionsLead> toLeads(AdmissionsLeadsResponseDto dto) {
    return [for (final item in dto.items) toLead(item)];
  }

  AdmissionsLead toLead(AdmissionsLeadDto dto) {
    final raw = dto.raw;
    return AdmissionsLead(
      id: raw['id'] as String? ?? '',
      parentName: raw['parentName'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      source: AdmissionsEnumCodec.parseLeadSource(raw['source'] as String?),
      campaign: raw['campaign'] as String? ?? '',
      stage: AdmissionsEnumCodec.parseLeadStage(raw['stage'] as String?),
      counselor: raw['counselor'] as String? ?? '',
      score: AdmissionsEnumCodec.parseLeadScore(raw['score'] as String?),
      nextFollowUpLabel: raw['nextFollowUpLabel'] as String? ?? '',
    );
  }

  LeadDetailData toLeadDetail(Map<String, dynamic> raw) {
    final activities = (raw['activities'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(toLeadActivityItem)
        .toList(growable: false);
    final followUps = (raw['followUps'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(toFollowUpRecord)
        .toList(growable: false);
    return LeadDetailData(
      lead: toLead(AdmissionsLeadDto.fromJson(raw)),
      email: raw['email'] as String? ?? '',
      address: raw['address'] as String? ?? '',
      createdLabel: raw['createdLabel'] as String? ?? '',
      lastActivityLabel: raw['lastActivityLabel'] as String? ?? '',
      notes: raw['notes'] as String? ?? '',
      activities: activities,
      followUpHistory: followUps,
    );
  }

  List<AdmissionsApplication> toApplications(
    AdmissionsApplicationsResponseDto dto,
  ) {
    return [for (final item in dto.items) toApplication(item)];
  }

  AdmissionsApplication toApplication(AdmissionsApplicationDto dto) {
    final raw = dto.raw;
    return AdmissionsApplication(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      parentName: raw['parentName'] as String? ?? '',
      submittedLabel: raw['submittedLabel'] as String? ?? '',
      status: AdmissionsEnumCodec.parseApplicationStatus(
        raw['status'] as String?,
      ),
      documentsComplete: raw['documentsComplete'] as int? ?? 0,
      documentsTotal: raw['documentsTotal'] as int? ?? 0,
      counselor: raw['counselor'] as String? ?? '',
    );
  }

  List<StudentDocumentRecord> toDocuments(AdmissionsDocumentsResponseDto dto) {
    return [for (final item in dto.items) toDocument(item)];
  }

  StudentDocumentRecord toDocument(StudentDocumentDto dto) {
    final raw = dto.raw;
    return StudentDocumentRecord(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      documentType: AdmissionsEnumCodec.parseDocumentType(
        raw['documentType'] as String?,
      ),
      isRequired: raw['isRequired'] as bool? ?? true,
      status: AdmissionsEnumCodec.parseDocumentStatus(
        raw['status'] as String?,
      ),
      uploadedLabel: raw['uploadedLabel'] as String? ?? '',
      verifiedBy: raw['verifiedBy'] as String?,
      leadId: raw['leadId'] as String? ?? '',
      hasFile: raw['hasFile'] as bool? ?? false,
    );
  }

  List<PendingEnrollmentRecord> toPendingEnrollments(
    AdmissionsEnrollmentsResponseDto dto,
  ) {
    return [for (final item in dto.items) toPendingEnrollment(item)];
  }

  PendingEnrollmentRecord toPendingEnrollment(PendingEnrollmentDto dto) {
    final raw = dto.raw;
    return PendingEnrollmentRecord(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      applicationId: raw['applicationId'] as String? ?? '',
      seekingClass: raw['seekingClass'] as String? ?? '',
      section: raw['section'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ?? '',
      guardianName: raw['guardianName'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      submittedAt: raw['submittedAt'] as String? ?? '',
      conversionStatus: AdmissionsEnumCodec.parseConversionStatus(
        raw['conversionStatus'] as String?,
      ),
      generatedAdmissionNumber: raw['generatedAdmissionNumber'] as String?,
      previewStudentId: raw['previewStudentId'] as String?,
      gender: raw['gender'] as String? ?? '',
      dateOfBirth: raw['dateOfBirth'] as String? ?? '',
    );
  }

  List<ApprovedStudentHandoff> toApprovedHandoffs(
    AdmissionsHandoffsResponseDto dto,
  ) {
    return [for (final item in dto.items) toApprovedHandoff(item)];
  }

  ApprovedStudentHandoff toApprovedHandoff(ApprovedStudentHandoffDto dto) {
    final raw = dto.raw;
    return ApprovedStudentHandoff(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      applicationId: raw['applicationId'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      needsTransport: raw['needsTransport'] as bool? ?? false,
      needsHostel: raw['needsHostel'] as bool? ?? false,
      selectedFeeStructureId: raw['selectedFeeStructureId'] as String?,
      handoffStatus: AdmissionsEnumCodec.parseFeeHandoffStatus(
        raw['handoffStatus'] as String?,
      ),
      previewStudentId: raw['previewStudentId'] as String? ?? '',
      sisHandoffLabel: raw['sisHandoffLabel'] as String? ?? '',
    );
  }

  List<FeeStructureOption> toFeeStructureOptions(
    AdmissionsFeeStructuresResponseDto dto,
  ) {
    return [for (final item in dto.items) toFeeStructureOption(item)];
  }

  FeeStructureOption toFeeStructureOption(FeeStructureOptionDto dto) {
    final raw = dto.raw;
    return FeeStructureOption(
      id: raw['id'] as String? ?? '',
      label: raw['label'] as String? ?? '',
      annualAmount: raw['annualAmount'] as String? ?? '',
      installments: raw['installments'] as int? ?? 1,
    );
  }

  List<ApprovalQueueItem> toApprovalQueue(
    AdmissionsApprovalQueueResponseDto dto,
  ) {
    return [for (final item in dto.items) toApprovalQueueItem(item)];
  }

  ApprovalQueueItem toApprovalQueueItem(ApprovalQueueItemDto dto) {
    final raw = dto.raw;
    return ApprovalQueueItem(
      id: raw['id'] as String? ?? '',
      applicationId: raw['applicationId'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      parentName: raw['parentName'] as String? ?? '',
      counselor: raw['counselor'] as String? ?? '',
      submittedLabel: raw['submittedLabel'] as String? ?? '',
      documentsComplete: raw['documentsComplete'] as int? ?? 0,
      documentsTotal: raw['documentsTotal'] as int? ?? 0,
      decision: AdmissionsEnumCodec.parseApprovalDecision(
        raw['decision'] as String?,
      ),
      aiScore: raw['aiScore'] as int? ?? 0,
    );
  }

  AdmissionsReportsData toReports(AdmissionsReportsDto dto) {
    final raw = dto.raw;
    return AdmissionsReportsData(
      funnelSegments:
          _mapChartSegments(raw['funnelSegments'] as List<dynamic>? ?? const []),
      sourceAnalysis: _mapSourceAnalysis(
        raw['sourceAnalysis'] as List<dynamic>? ?? const [],
      ),
      counselorPerformance: _mapCounselorPerformance(
        raw['counselorPerformance'] as List<dynamic>? ?? const [],
      ),
      applicationStatus: _mapApplicationStatusReport(
        raw['applicationStatus'] as List<dynamic>? ?? const [],
      ),
    );
  }

  AdmissionsSettingsData toSettings(AdmissionsSettingsDto dto) {
    final raw = dto.raw;
    return AdmissionsSettingsData(
      leadStages: _mapLeadStageConfigs(
        raw['leadStages'] as List<dynamic>? ?? const [],
      ),
      leadScores: _mapLeadScoreConfigs(
        raw['leadScores'] as List<dynamic>? ?? const [],
      ),
      workflowSteps: _mapWorkflowConfigs(
        raw['workflowSteps'] as List<dynamic>? ?? const [],
      ),
      assignmentRules: _mapAssignmentRules(
        raw['assignmentRules'] as List<dynamic>? ?? const [],
      ),
      notificationTemplates: _mapNotificationTemplates(
        raw['notificationTemplates'] as List<dynamic>? ?? const [],
      ),
    );
  }

  EnrollmentFormState toEnrollmentPrefill(EnrollmentPrefillDto dto) {
    final raw = dto.raw;
    final student = raw['student'] as Map<String, dynamic>? ?? const {};
    final parent = raw['parent'] as Map<String, dynamic>? ?? const {};
    final academic = raw['academic'] as Map<String, dynamic>? ?? const {};
    return EnrollmentFormState(
      currentStep: AdmissionsEnumCodec.parseEnrollmentStep(
        raw['currentStep'] as String?,
      ),
      student: EnrollmentStudentProfile(
        fullName: student['fullName'] as String? ?? '',
        dateOfBirth: student['dateOfBirth'] as String? ?? '',
        gender: student['gender'] as String? ?? '',
        aadhaar: student['aadhaar'] as String? ?? '',
      ),
      parent: EnrollmentParentInfo(
        guardianName: parent['guardianName'] as String? ?? '',
        relationship: parent['relationship'] as String? ?? '',
        phone: parent['phone'] as String? ?? '',
        email: parent['email'] as String? ?? '',
        address: parent['address'] as String? ?? '',
      ),
      academic: EnrollmentAcademicInfo(
        seekingClass: academic['seekingClass'] as String? ?? '',
        section: academic['section'] as String? ?? '',
        academicYear: academic['academicYear'] as String? ?? '2026–27',
        previousSchool: academic['previousSchool'] as String? ?? '',
        needsTransport: academic['needsTransport'] as bool? ?? false,
        needsHostel: academic['needsHostel'] as bool? ?? false,
      ),
      isSubmitting: raw['isSubmitting'] as bool? ?? false,
      isSubmitted: raw['isSubmitted'] as bool? ?? false,
      generatedAdmissionNumber: raw['generatedAdmissionNumber'] as String?,
    );
  }

  List<AdmissionsKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AdmissionsKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: _kpiIcon(item['id'] as String? ?? ''),
            accentName: item['accentName'] as String? ?? 'neutral',
          ),
    ];
  }

  IconData _kpiIcon(String id) => switch (id) {
        'total_leads' => Icons.people_outline,
        'hot_leads' => Icons.local_fire_department_outlined,
        'visits' => Icons.event_available_outlined,
        'confirmed' => Icons.verified_outlined,
        'joined' => Icons.school_outlined,
        'conversion' => Icons.trending_up,
        _ => Icons.insights_outlined,
      };

  List<PipelineStageSummary> _mapPipeline(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PipelineStageSummary(
            stage: AdmissionsEnumCodec.parseLeadStage(item['stage'] as String?),
            count: item['count'] as int? ?? 0,
            leads: _mapPipelinePreviews(
              item['leads'] as List<dynamic>? ?? const [],
            ),
          ),
    ];
  }

  List<PipelineLeadPreview> _mapPipelinePreviews(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PipelineLeadPreview(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            score: AdmissionsEnumCodec.parseLeadScore(item['score'] as String?),
            source:
                AdmissionsEnumCodec.parseLeadSource(item['source'] as String?),
            daysInStage: item['daysInStage'] as int? ?? 0,
          ),
    ];
  }

  List<ChartSegment> _mapChartSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ChartSegment(
            label: item['label'] as String? ?? '',
            value: item['value'] as int? ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<AdmissionsFollowUp> _mapFollowUps(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AdmissionsFollowUp(
            id: item['id'] as String? ?? '',
            dueLabel: item['dueLabel'] as String? ?? '',
            leadName: item['leadName'] as String? ?? '',
            task: item['task'] as String? ?? '',
            counselor: item['counselor'] as String? ?? '',
            priority: AdmissionsEnumCodec.parseFollowUpPriority(
              item['priority'] as String?,
            ),
            status: AdmissionsEnumCodec.parseFollowUpStatus(
              item['status'] as String?,
            ),
          ),
    ];
  }

  List<CounselorLeaderboardEntry> _mapLeaderboard(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          CounselorLeaderboardEntry(
            counselor: item['counselor'] as String? ?? '',
            leadsHandled: item['leadsHandled'] as int? ?? 0,
            conversions: item['conversions'] as int? ?? 0,
            conversionRate:
                (item['conversionRate'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<SourceLeadAnalysisRow> _mapSourceAnalysis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SourceLeadAnalysisRow(
            source:
                AdmissionsEnumCodec.parseLeadSource(item['source'] as String?),
            leads: item['leads'] as int? ?? 0,
            converted: item['converted'] as int? ?? 0,
            conversionRate:
                (item['conversionRate'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<CounselorPerformanceRow> _mapCounselorPerformance(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          CounselorPerformanceRow(
            counselor: item['counselor'] as String? ?? '',
            leads: item['leads'] as int? ?? 0,
            applications: item['applications'] as int? ?? 0,
            approved: item['approved'] as int? ?? 0,
            conversionRate:
                (item['conversionRate'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<ApplicationStatusReportRow> _mapApplicationStatusReport(
    List<dynamic> items,
  ) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ApplicationStatusReportRow(
            status: AdmissionsEnumCodec.parseApplicationStatus(
              item['status'] as String?,
            ),
            count: item['count'] as int? ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<LeadStageConfig> _mapLeadStageConfigs(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LeadStageConfig(
            stage: AdmissionsEnumCodec.parseLeadStage(item['stage'] as String?),
            enabled: item['enabled'] as bool? ?? true,
            autoAdvanceDays: item['autoAdvanceDays'] as int?,
          ),
    ];
  }

  List<LeadScoreConfig> _mapLeadScoreConfigs(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LeadScoreConfig(
            score: AdmissionsEnumCodec.parseLeadScore(item['score'] as String?),
            minEngagement: item['minEngagement'] as int? ?? 0,
            followUpHours: item['followUpHours'] as int? ?? 24,
          ),
    ];
  }

  List<ApplicationWorkflowConfig> _mapWorkflowConfigs(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ApplicationWorkflowConfig(
            status: AdmissionsEnumCodec.parseApplicationStatus(
              item['status'] as String?,
            ),
            enabled: item['enabled'] as bool? ?? true,
            requiresPrincipalApproval:
                item['requiresPrincipalApproval'] as bool? ?? false,
          ),
    ];
  }

  List<CounselorAssignmentRule> _mapAssignmentRules(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          CounselorAssignmentRule(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            strategy: item['strategy'] as String? ?? '',
            enabled: item['enabled'] as bool? ?? true,
          ),
    ];
  }

  List<NotificationTemplate> _mapNotificationTemplates(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          NotificationTemplate(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            channel: item['channel'] as String? ?? '',
            preview: item['preview'] as String? ?? '',
            enabled: item['enabled'] as bool? ?? true,
          ),
    ];
  }

  LeadFollowUpRecord toFollowUpRecord(Map<String, dynamic> raw) {
    return LeadFollowUpRecord(
      id: raw['id'] as String? ?? '',
      scheduledLabel:
          raw['scheduledLabel'] as String? ?? raw['scheduled_label'] as String? ?? '',
      completedLabel:
          raw['completedLabel'] as String? ?? raw['completed_label'] as String? ?? '',
      task: raw['task'] as String? ?? '',
      counselor: raw['counselor'] as String? ?? '',
      status: AdmissionsEnumCodec.parseFollowUpStatus(raw['status'] as String?),
      outcome: raw['outcome'] as String? ?? '',
    );
  }

  LeadActivityItem toLeadActivityItem(Map<String, dynamic> raw) {
    return LeadActivityItem(
      id: raw['id'] as String? ?? '',
      timestampLabel:
          raw['timestampLabel'] as String? ?? raw['timestamp_label'] as String? ?? '',
      title: raw['title'] as String? ?? 'Note added',
      description: raw['description'] as String? ?? raw['content'] as String? ?? '',
      actor: raw['actor'] as String? ?? '',
      type: AdmissionsEnumCodec.parseLeadActivityType(raw['type'] as String?),
    );
  }

  CounselorNote toCounselorNote(Map<String, dynamic> raw) {
    return CounselorNote(
      id: raw['id'] as String? ?? '',
      author: raw['author'] as String? ?? '',
      timestampLabel:
          raw['timestampLabel'] as String? ?? raw['timestamp_label'] as String? ?? '',
      content: raw['content'] as String? ?? '',
    );
  }

  GeneratedAdmissionNumber toGeneratedAdmissionNumber(
    Map<String, dynamic> raw,
  ) {
    return GeneratedAdmissionNumber(
      admissionNumber:
          raw['admissionNumber'] as String? ??
          raw['admission_number'] as String? ??
          '',
    );
  }
}
