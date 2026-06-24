import 'package:flutter/material.dart';

import '../../../features/admissions/admissions_models.dart';
import '../../../features/admissions/admissions_requests.dart';
import '../interfaces/admissions_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';
import '../../tenant/tenant_mock_scope.dart';
import 'mock_admissions_sis_bridge.dart';
import 'mock_admissions_write_store.dart';

/// In-memory admissions data for MVP screens.
class MockAdmissionsRepository implements AdmissionsRepository {
  @override
  Future<AdmissionsDashboardData> getDashboard(
      {required RepositoryQuery query}) async {
    return AdmissionsDashboardData(
      kpis: const [
        AdmissionsKpi(
          id: 'total_leads',
          value: '248',
          label: 'Total Leads (MTD)',
          icon: Icons.people_outline,
          accentName: 'primary',
        ),
        AdmissionsKpi(
          id: 'hot_leads',
          value: '34',
          label: 'Hot Leads',
          icon: Icons.local_fire_department_outlined,
          accentName: 'error',
        ),
        AdmissionsKpi(
          id: 'visits',
          value: '18',
          label: 'Visits Scheduled',
          icon: Icons.event_available_outlined,
          accentName: 'warning',
        ),
        AdmissionsKpi(
          id: 'confirmed',
          value: '42',
          label: 'Confirmed',
          icon: Icons.verified_outlined,
          accentName: 'success',
        ),
        AdmissionsKpi(
          id: 'joined',
          value: '36',
          label: 'Joined',
          icon: Icons.school_outlined,
          accentName: 'success',
        ),
        AdmissionsKpi(
          id: 'conversion',
          value: '14.5%',
          label: 'Conversion Rate',
          icon: Icons.trending_up,
          accentName: 'neutral',
        ),
      ],
      pipeline: [
        PipelineStageSummary(
          stage: LeadStage.newEnquiry,
          count: 28,
          leads: _previewLeads(LeadStage.newEnquiry),
        ),
        PipelineStageSummary(
          stage: LeadStage.contacted,
          count: 45,
          leads: _previewLeads(LeadStage.contacted),
        ),
        PipelineStageSummary(
          stage: LeadStage.schoolVisit,
          count: 18,
          leads: _previewLeads(LeadStage.schoolVisit),
        ),
        PipelineStageSummary(
          stage: LeadStage.demoClass,
          count: 12,
          leads: _previewLeads(LeadStage.demoClass),
        ),
        PipelineStageSummary(
          stage: LeadStage.followUp,
          count: 34,
          leads: _previewLeads(LeadStage.followUp),
        ),
        PipelineStageSummary(
          stage: LeadStage.admissionConfirmed,
          count: 42,
          leads: _previewLeads(LeadStage.admissionConfirmed),
        ),
        PipelineStageSummary(
          stage: LeadStage.joined,
          count: 36,
          leads: _previewLeads(LeadStage.joined),
        ),
      ],
      funnelSegments: const [
        ChartSegment(label: 'Enquiries', value: 312, percent: 100),
        ChartSegment(label: 'Qualified', value: 248, percent: 79.5),
        ChartSegment(label: 'Visits', value: 96, percent: 30.8),
        ChartSegment(label: 'Confirmed', value: 42, percent: 13.5),
        ChartSegment(label: 'Joined', value: 36, percent: 11.5),
      ],
      sourceSegments: const [
        ChartSegment(label: 'Walk-in', value: 82, percent: 33.1),
        ChartSegment(label: 'Website', value: 58, percent: 23.4),
        ChartSegment(label: 'WhatsApp', value: 44, percent: 17.7),
        ChartSegment(label: 'Referral', value: 36, percent: 14.5),
        ChartSegment(label: 'Google Ads', value: 18, percent: 7.3),
        ChartSegment(label: 'Facebook', value: 10, percent: 4.0),
      ],
      followUps: const [
        AdmissionsFollowUp(
          id: 'fu_1',
          dueLabel: '10:00 AM',
          leadName: 'Ananya Reddy',
          task: 'Call parent — fee discussion',
          counselor: 'Meera N.',
          priority: FollowUpPriority.high,
          status: FollowUpStatus.pending,
        ),
        AdmissionsFollowUp(
          id: 'fu_2',
          dueLabel: '11:30 AM',
          leadName: 'Karthik Sharma',
          task: 'School visit reminder',
          counselor: 'Rahul V.',
          priority: FollowUpPriority.medium,
          status: FollowUpStatus.pending,
        ),
        AdmissionsFollowUp(
          id: 'fu_3',
          dueLabel: '2:00 PM',
          leadName: 'Priya Menon',
          task: 'Send brochure on WhatsApp',
          counselor: 'Meera N.',
          priority: FollowUpPriority.low,
          status: FollowUpStatus.pending,
        ),
        AdmissionsFollowUp(
          id: 'fu_4',
          dueLabel: 'Yesterday',
          leadName: 'Arjun Patel',
          task: 'Demo class feedback',
          counselor: 'Sneha K.',
          priority: FollowUpPriority.high,
          status: FollowUpStatus.overdue,
        ),
      ],
      leaderboard: const [
        CounselorLeaderboardEntry(
          counselor: 'Meera N.',
          leadsHandled: 68,
          conversions: 14,
          conversionRate: 20.6,
        ),
        CounselorLeaderboardEntry(
          counselor: 'Rahul V.',
          leadsHandled: 54,
          conversions: 9,
          conversionRate: 16.7,
        ),
        CounselorLeaderboardEntry(
          counselor: 'Sneha K.',
          leadsHandled: 47,
          conversions: 8,
          conversionRate: 17.0,
        ),
        CounselorLeaderboardEntry(
          counselor: 'Arun D.',
          leadsHandled: 39,
          conversions: 5,
          conversionRate: 12.8,
        ),
      ],
      aiInsight:
          'Conversion drops 18% after Demo Class. Recommend same-day follow-up calls for visit-completed leads.',
      aiActionLabel: 'View recommendations',
    );
  }

  @override
  Future<PaginatedResult<AdmissionsLead>> getLeads({
    required RepositoryQuery query,
  }) async {
    final leads = await _loadAllLeads(query);
    return PaginatedResult.fromItems(
      leads,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  Future<List<AdmissionsLead>> _loadAllLeads(RepositoryQuery query) async {
    if (_store.leads != null) {
      return TenantMockScope.filter(
        query: query,
        items: List.from(_store.leads!),
      );
    }
    final leads = [
      const AdmissionsLead(
        id: 'LD-1042',
        parentName: 'Rajesh Reddy',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        phone: '+91 98765 43210',
        source: LeadSource.walkIn,
        campaign: 'Summer Open Day',
        stage: LeadStage.schoolVisit,
        counselor: 'Meera N.',
        score: LeadScore.hot,
        nextFollowUpLabel: '5 Jun · 10:00 AM',
      ),
      const AdmissionsLead(
        id: 'LD-1038',
        parentName: 'Lakshmi Sharma',
        studentName: 'Karthik Sharma',
        classLabel: '8',
        phone: '+91 91234 56789',
        source: LeadSource.website,
        campaign: 'Organic — Homepage',
        stage: LeadStage.demoClass,
        counselor: 'Rahul V.',
        score: LeadScore.warm,
        nextFollowUpLabel: '6 Jun · 11:30 AM',
      ),
      const AdmissionsLead(
        id: 'LD-1031',
        parentName: 'Suresh Menon',
        studentName: 'Priya Menon',
        classLabel: '3',
        phone: '+91 99887 76655',
        source: LeadSource.whatsapp,
        campaign: 'WA Broadcast Q2',
        stage: LeadStage.followUp,
        counselor: 'Meera N.',
        score: LeadScore.hot,
        nextFollowUpLabel: '5 Jun · 2:00 PM',
      ),
      const AdmissionsLead(
        id: 'LD-1024',
        parentName: 'Anita Patel',
        studentName: 'Arjun Patel',
        classLabel: '10',
        phone: '+91 97654 32109',
        source: LeadSource.referral,
        campaign: 'Parent referral — Grade 9',
        stage: LeadStage.admissionConfirmed,
        counselor: 'Sneha K.',
        score: LeadScore.warm,
        nextFollowUpLabel: '7 Jun · 9:00 AM',
      ),
      const AdmissionsLead(
        id: 'LD-1019',
        parentName: 'Vikram Iyer',
        studentName: 'Divya Iyer',
        classLabel: '6',
        phone: '+91 96543 21098',
        source: LeadSource.googleAds,
        campaign: 'Search — Best school',
        stage: LeadStage.contacted,
        counselor: 'Arun D.',
        score: LeadScore.cold,
        nextFollowUpLabel: '8 Jun · 4:00 PM',
      ),
      const AdmissionsLead(
        id: 'LD-1012',
        parentName: 'Meena Krishnan',
        studentName: 'Rohan Krishnan',
        classLabel: '1',
        phone: '+91 95432 10987',
        source: LeadSource.facebook,
        campaign: 'FB Lead Gen — Nursery',
        stage: LeadStage.newEnquiry,
        counselor: 'Rahul V.',
        score: LeadScore.warm,
        nextFollowUpLabel: '5 Jun · 5:30 PM',
      ),
      const AdmissionsLead(
        id: 'LD-1008',
        parentName: 'Joseph Thomas',
        studentName: 'Emma Thomas',
        classLabel: '7',
        phone: '+91 94321 09876',
        source: LeadSource.walkIn,
        campaign: 'Campus tour — May',
        stage: LeadStage.joined,
        counselor: 'Sneha K.',
        score: LeadScore.hot,
        nextFollowUpLabel: 'Completed',
      ),
    ];
    _store.leads = List.from(leads);
    return TenantMockScope.filter(query: query, items: leads);
  }

  @override
  Future<PaginatedResult<AdmissionsApplication>> getApplications({
    required RepositoryQuery query,
  }) async {
    final applications = await _loadAllApplications(query);
    return PaginatedResult.fromItems(
      applications,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  Future<List<AdmissionsApplication>> _loadAllApplications(
    RepositoryQuery query,
  ) async {
    if (_store.applications != null) {
      return List.from(_store.applications!);
    }
    final applications = [
      const AdmissionsApplication(
        id: 'APP-2208',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        parentName: 'Rajesh Reddy',
        submittedLabel: '4 Jun 2026',
        status: ApplicationStatus.underReview,
        documentsComplete: 4,
        documentsTotal: 5,
        counselor: 'Meera N.',
      ),
      const AdmissionsApplication(
        id: 'APP-2201',
        studentName: 'Karthik Sharma',
        classLabel: '8',
        parentName: 'Lakshmi Sharma',
        submittedLabel: '3 Jun 2026',
        status: ApplicationStatus.documentsPending,
        documentsComplete: 2,
        documentsTotal: 5,
        counselor: 'Rahul V.',
      ),
      const AdmissionsApplication(
        id: 'APP-2194',
        studentName: 'Priya Menon',
        classLabel: '3',
        parentName: 'Suresh Menon',
        submittedLabel: '2 Jun 2026',
        status: ApplicationStatus.submitted,
        documentsComplete: 5,
        documentsTotal: 5,
        counselor: 'Meera N.',
      ),
      const AdmissionsApplication(
        id: 'APP-2188',
        studentName: 'Arjun Patel',
        classLabel: '10',
        parentName: 'Anita Patel',
        submittedLabel: '1 Jun 2026',
        status: ApplicationStatus.approved,
        documentsComplete: 5,
        documentsTotal: 5,
        counselor: 'Sneha K.',
      ),
      const AdmissionsApplication(
        id: 'APP-2180',
        studentName: 'Divya Iyer',
        classLabel: '6',
        parentName: 'Vikram Iyer',
        submittedLabel: '—',
        status: ApplicationStatus.draft,
        documentsComplete: 0,
        documentsTotal: 5,
        counselor: 'Arun D.',
      ),
      const AdmissionsApplication(
        id: 'APP-2175',
        studentName: 'Emma Thomas',
        classLabel: '7',
        parentName: 'Joseph Thomas',
        submittedLabel: '28 May 2026',
        status: ApplicationStatus.rejected,
        documentsComplete: 3,
        documentsTotal: 5,
        counselor: 'Sneha K.',
      ),
    ];
    _store.applications = List.from(applications);
    return applications;
  }

  @override
  Future<PaginatedResult<StudentDocumentRecord>> getDocuments({
    required RepositoryQuery query,
  }) async {
    if (_store.documents != null) {
      return paginateList(List.from(_store.documents!), query);
    }
    final documents = [
      const StudentDocumentRecord(
        id: 'doc_1',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        documentType: DocumentType.birthCertificate,
        isRequired: true,
        status: DocumentVerificationStatus.verified,
        uploadedLabel: '2 Jun 2026',
        verifiedBy: 'Meera N.',
        leadId: 'LD-1042',
      ),
      const StudentDocumentRecord(
        id: 'doc_2',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        documentType: DocumentType.aadhaar,
        isRequired: true,
        status: DocumentVerificationStatus.uploaded,
        uploadedLabel: '3 Jun 2026',
        verifiedBy: null,
        leadId: 'LD-1042',
      ),
      const StudentDocumentRecord(
        id: 'doc_3',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        documentType: DocumentType.marksMemo,
        isRequired: true,
        status: DocumentVerificationStatus.missing,
        uploadedLabel: '—',
        verifiedBy: null,
        leadId: 'LD-1042',
      ),
      const StudentDocumentRecord(
        id: 'doc_4',
        studentName: 'Karthik Sharma',
        classLabel: '8',
        documentType: DocumentType.transferCertificate,
        isRequired: true,
        status: DocumentVerificationStatus.rejected,
        uploadedLabel: '1 Jun 2026',
        verifiedBy: 'Rahul V.',
        leadId: 'LD-1038',
      ),
      const StudentDocumentRecord(
        id: 'doc_5',
        studentName: 'Karthik Sharma',
        classLabel: '8',
        documentType: DocumentType.photos,
        isRequired: false,
        status: DocumentVerificationStatus.verified,
        uploadedLabel: '1 Jun 2026',
        verifiedBy: 'Rahul V.',
        leadId: 'LD-1038',
      ),
      const StudentDocumentRecord(
        id: 'doc_6',
        studentName: 'Arjun Patel',
        classLabel: '10',
        documentType: DocumentType.medical,
        isRequired: true,
        status: DocumentVerificationStatus.uploaded,
        uploadedLabel: '4 Jun 2026',
        verifiedBy: null,
        leadId: 'LD-1024',
      ),
    ];
    _store.documents = List.from(documents);
    return paginateList(documents, query);
  }

  @override
  Future<PaginatedResult<PendingEnrollmentRecord>> getPendingEnrollments({
    required RepositoryQuery query,
  }) async {
    final enrollments = await _loadAllEnrollments(query);
    return paginateList(enrollments, query);
  }

  Future<List<PendingEnrollmentRecord>> _loadAllEnrollments(
    RepositoryQuery query,
  ) async {
    if (_store.enrollments != null) {
      return TenantMockScope.filter(
        query: query,
        items: List.from(_store.enrollments!),
      );
    }
    return const [
      PendingEnrollmentRecord(
        id: 'enr_1',
        studentName: 'Ananya Reddy',
        applicationId: 'APP-2208',
        seekingClass: '5',
        section: 'A',
        academicYear: '2026–27',
        guardianName: 'Rajesh Reddy',
        phone: '+91 98765 43210',
        submittedAt: 'Today',
        conversionStatus: EnrollmentConversionStatus.pending,
        gender: 'Female',
        dateOfBirth: '12 Mar 2016',
      ),
      PendingEnrollmentRecord(
        id: 'enr_2',
        studentName: 'Vihaan Sharma',
        applicationId: 'APP-2215',
        seekingClass: '8',
        section: 'B',
        academicYear: '2026–27',
        guardianName: 'Priya Sharma',
        phone: '+91 91234 56780',
        submittedAt: 'Yesterday',
        conversionStatus: EnrollmentConversionStatus.pending,
        gender: 'Male',
        dateOfBirth: '05 Aug 2013',
      ),
      PendingEnrollmentRecord(
        id: 'enr_3',
        studentName: 'Emma Thomas',
        applicationId: 'APP-2175',
        seekingClass: '7',
        section: 'A',
        academicYear: '2026–27',
        guardianName: 'David Thomas',
        phone: '+91 99887 76655',
        submittedAt: '3 days ago',
        conversionStatus: EnrollmentConversionStatus.converted,
        generatedAdmissionNumber: 'ADM-2026-0135',
        previewStudentId: 'SIS-STU-10418',
        gender: 'Female',
        dateOfBirth: '22 Jan 2014',
      ),
    ];
  }

  @override
  Future<PaginatedResult<ApprovedStudentHandoff>> getApprovedHandoffs({
    required RepositoryQuery query,
  }) async {
    return PaginatedResult.fromItems(
      await _loadAllHandoffs(query),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  Future<List<ApprovedStudentHandoff>> _loadAllHandoffs(
    RepositoryQuery query,
  ) async {
    if (_store.handoffs != null) {
      return List.from(_store.handoffs!);
    }
    const seed = [
      ApprovedStudentHandoff(
        id: 'handoff_1',
        studentName: 'Arjun Patel',
        classLabel: '10',
        applicationId: 'APP-2188',
        admissionNumber: 'ADM-2026-0138',
        needsTransport: false,
        needsHostel: false,
        selectedFeeStructureId: 'fee_std',
        handoffStatus: FeeHandoffStatus.sentToFinance,
        previewStudentId: 'SIS-STU-10421',
        sisHandoffLabel: 'Queued for Student SIS',
      ),
      ApprovedStudentHandoff(
        id: 'handoff_2',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        applicationId: 'APP-2208',
        admissionNumber: 'ADM-2026-0142',
        needsTransport: true,
        needsHostel: false,
        selectedFeeStructureId: 'fee_premium',
        handoffStatus: FeeHandoffStatus.pending,
        previewStudentId: 'SIS-STU-10422',
        sisHandoffLabel: 'Pending finance confirmation',
      ),
      ApprovedStudentHandoff(
        id: 'handoff_3',
        studentName: 'Emma Thomas',
        classLabel: '7',
        applicationId: 'APP-2175',
        admissionNumber: 'ADM-2026-0135',
        needsTransport: true,
        needsHostel: true,
        selectedFeeStructureId: 'fee_hostel',
        handoffStatus: FeeHandoffStatus.completed,
        previewStudentId: 'SIS-STU-10418',
        sisHandoffLabel: 'Active in Student SIS',
      ),
    ];
    _store.handoffs = List.from(seed);
    return _store.handoffs!;
  }

  @override
  Future<PaginatedResult<FeeStructureOption>> getFeeStructureOptions({
    required RepositoryQuery query,
  }) async {
    return paginateList(const [
      FeeStructureOption(
        id: 'fee_std',
        label: 'Standard CBSE',
        annualAmount: '₹1,85,000',
        installments: 3,
      ),
      FeeStructureOption(
        id: 'fee_premium',
        label: 'Premium + Transport',
        annualAmount: '₹2,15,000',
        installments: 3,
      ),
      FeeStructureOption(
        id: 'fee_hostel',
        label: 'Boarding Package',
        annualAmount: '₹3,40,000',
        installments: 4,
      ),
    ], query);
  }

  @override
  Future<PaginatedResult<ApprovalQueueItem>> getApprovalQueue({
    required RepositoryQuery query,
  }) async {
    final queue = await _loadAllApprovalQueue(query);
    return PaginatedResult.fromItems(
      queue,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  Future<List<ApprovalQueueItem>> _loadAllApprovalQueue(
    RepositoryQuery query,
  ) async {
    if (_store.approvalQueue != null) {
      return List.from(_store.approvalQueue!);
    }
    const queue = [
      ApprovalQueueItem(
        id: 'appr_1',
        applicationId: 'APP-2208',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        parentName: 'Rajesh Reddy',
        counselor: 'Meera N.',
        submittedLabel: '4 Jun 2026',
        documentsComplete: 4,
        documentsTotal: 5,
        decision: ApprovalDecision.pending,
        aiScore: 82,
      ),
      ApprovalQueueItem(
        id: 'appr_2',
        applicationId: 'APP-2194',
        studentName: 'Priya Menon',
        classLabel: '3',
        parentName: 'Suresh Menon',
        counselor: 'Meera N.',
        submittedLabel: '2 Jun 2026',
        documentsComplete: 5,
        documentsTotal: 5,
        decision: ApprovalDecision.pending,
        aiScore: 76,
      ),
      ApprovalQueueItem(
        id: 'appr_3',
        applicationId: 'APP-2188',
        studentName: 'Arjun Patel',
        classLabel: '10',
        parentName: 'Anita Patel',
        counselor: 'Sneha K.',
        submittedLabel: '1 Jun 2026',
        documentsComplete: 5,
        documentsTotal: 5,
        decision: ApprovalDecision.approved,
        aiScore: 91,
      ),
    ];
    _store.approvalQueue = List.from(queue);
    return queue;
  }

  @override
  Future<AdmissionsReportsData> getReports(
      {required RepositoryQuery query}) async {
    return const AdmissionsReportsData(
      funnelSegments: [
        ChartSegment(label: 'Enquiries', value: 312, percent: 100),
        ChartSegment(label: 'Qualified', value: 248, percent: 79.5),
        ChartSegment(label: 'Applications', value: 96, percent: 30.8),
        ChartSegment(label: 'Approved', value: 42, percent: 13.5),
        ChartSegment(label: 'Joined', value: 36, percent: 11.5),
      ],
      sourceAnalysis: [
        SourceLeadAnalysisRow(
          source: LeadSource.walkIn,
          leads: 82,
          converted: 28,
          conversionRate: 34.1,
        ),
        SourceLeadAnalysisRow(
          source: LeadSource.website,
          leads: 58,
          converted: 16,
          conversionRate: 27.6,
        ),
        SourceLeadAnalysisRow(
          source: LeadSource.whatsapp,
          leads: 44,
          converted: 12,
          conversionRate: 27.3,
        ),
        SourceLeadAnalysisRow(
          source: LeadSource.referral,
          leads: 36,
          converted: 14,
          conversionRate: 38.9,
        ),
      ],
      counselorPerformance: [
        CounselorPerformanceRow(
          counselor: 'Meera N.',
          leads: 68,
          applications: 24,
          approved: 14,
          conversionRate: 20.6,
        ),
        CounselorPerformanceRow(
          counselor: 'Rahul V.',
          leads: 54,
          applications: 18,
          approved: 9,
          conversionRate: 16.7,
        ),
        CounselorPerformanceRow(
          counselor: 'Sneha K.',
          leads: 47,
          applications: 16,
          approved: 8,
          conversionRate: 17.0,
        ),
      ],
      applicationStatus: [
        ApplicationStatusReportRow(
          status: ApplicationStatus.draft,
          count: 8,
          percent: 12.7,
        ),
        ApplicationStatusReportRow(
          status: ApplicationStatus.submitted,
          count: 18,
          percent: 28.6,
        ),
        ApplicationStatusReportRow(
          status: ApplicationStatus.underReview,
          count: 14,
          percent: 22.2,
        ),
        ApplicationStatusReportRow(
          status: ApplicationStatus.approved,
          count: 16,
          percent: 25.4,
        ),
        ApplicationStatusReportRow(
          status: ApplicationStatus.rejected,
          count: 7,
          percent: 11.1,
        ),
      ],
    );
  }

  @override
  Future<AdmissionsSettingsData> getSettings(
      {required RepositoryQuery query}) async {
    return _store.settings ??= _defaultSettings();
  }

  @override
  Future<AdmissionsSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateAdmissionsSettingsRequest request,
  }) async {
    final current = await getSettings(query: query);
    final updates = {
      for (final update in request.updates)
        '${update.sectionId}:${update.itemId}': update.value,
    };
    final next = AdmissionsSettingsData(
      leadStages: [
        for (final stage in current.leadStages)
          LeadStageConfig(
            stage: stage.stage,
            enabled: _resolveBoolUpdate(
              updates,
              sectionId: 'leadStages',
              itemId: '${stage.stage.name}.enabled',
              fallback: stage.enabled,
            ),
            autoAdvanceDays: _resolveIntUpdate(
              updates,
              sectionId: 'leadStages',
              itemId: '${stage.stage.name}.autoAdvanceDays',
              fallback: stage.autoAdvanceDays,
            ),
          ),
      ],
      leadScores: [
        for (final score in current.leadScores)
          LeadScoreConfig(
            score: score.score,
            minEngagement: _resolveIntUpdate(
                  updates,
                  sectionId: 'leadScores',
                  itemId: '${score.score.name}.minEngagement',
                  fallback: score.minEngagement,
                ) ??
                score.minEngagement,
            followUpHours: _resolveIntUpdate(
                  updates,
                  sectionId: 'leadScores',
                  itemId: '${score.score.name}.followUpHours',
                  fallback: score.followUpHours,
                ) ??
                score.followUpHours,
          ),
      ],
      workflowSteps: [
        for (final step in current.workflowSteps)
          ApplicationWorkflowConfig(
            status: step.status,
            enabled: _resolveBoolUpdate(
              updates,
              sectionId: 'workflowSteps',
              itemId: '${step.status.name}.enabled',
              fallback: step.enabled,
            ),
            requiresPrincipalApproval: _resolveBoolUpdate(
              updates,
              sectionId: 'workflowSteps',
              itemId: '${step.status.name}.requiresPrincipalApproval',
              fallback: step.requiresPrincipalApproval,
            ),
          ),
      ],
      assignmentRules: [
        for (final rule in current.assignmentRules)
          CounselorAssignmentRule(
            id: rule.id,
            label: rule.label,
            strategy: rule.strategy,
            enabled: _resolveBoolUpdate(
              updates,
              sectionId: 'assignmentRules',
              itemId: '${rule.id}.enabled',
              fallback: rule.enabled,
            ),
          ),
      ],
      notificationTemplates: [
        for (final template in current.notificationTemplates)
          NotificationTemplate(
            id: template.id,
            name: template.name,
            channel: template.channel,
            preview: template.preview,
            enabled: _resolveBoolUpdate(
              updates,
              sectionId: 'notificationTemplates',
              itemId: '${template.id}.enabled',
              fallback: template.enabled,
            ),
          ),
      ],
    );
    _store.settings = next;
    return next;
  }

  @override
  Future<EnrollmentFormState> getEnrollmentPrefill(
      {required RepositoryQuery query}) async {
    final lastLead = _store.lastCreatedLead;
    if (lastLead != null) {
      return EnrollmentFormState(
        student: EnrollmentStudentProfile(
          fullName: lastLead.studentName,
          dateOfBirth: '12 Mar 2016',
          gender: 'Female',
          aadhaar: '123456789012',
        ),
        parent: EnrollmentParentInfo(
          guardianName: lastLead.parentName,
          relationship: 'Father',
          phone: lastLead.phone.replaceAll(RegExp(r'[^\d]'), '').length >= 10
              ? lastLead.phone
              : '+91 98765 43210',
          email: 'parent.e2e@email.com',
          address: '12, Lake View Colony, Hyderabad',
        ),
        academic: EnrollmentAcademicInfo(
          seekingClass: lastLead.classLabel,
          section: 'A',
          academicYear: '2026–27',
          previousSchool: 'Previous school',
          needsTransport: false,
          needsHostel: false,
        ),
      );
    }
    return const EnrollmentFormState(
      student: EnrollmentStudentProfile(
        fullName: 'Ananya Reddy',
        dateOfBirth: '12 Mar 2016',
        gender: 'Female',
        aadhaar: '1234-5678-9012',
      ),
      parent: EnrollmentParentInfo(
        guardianName: 'Rajesh Reddy',
        relationship: 'Father',
        phone: '+91 98765 43210',
        email: 'rajesh.reddy@email.com',
        address: '12, Lake View Colony, Hyderabad',
      ),
      academic: EnrollmentAcademicInfo(
        seekingClass: '5',
        section: 'A',
        academicYear: '2026–27',
        previousSchool: 'Little Scholars Academy',
        needsTransport: true,
        needsHostel: false,
      ),
    );
  }

  List<PipelineLeadPreview> _previewLeads(LeadStage stage) {
    return [
      PipelineLeadPreview(
        id: '${stage.name}_1',
        studentName: 'Ananya Reddy',
        classLabel: '5',
        score: LeadScore.hot,
        source: LeadSource.walkIn,
        daysInStage: 2,
      ),
      PipelineLeadPreview(
        id: '${stage.name}_2',
        studentName: 'Karthik Sharma',
        classLabel: '8',
        score: LeadScore.warm,
        source: LeadSource.website,
        daysInStage: 4,
      ),
    ];
  }

  AdmissionsSettingsData _defaultSettings() {
    return AdmissionsSettingsData(
      leadStages: [
        for (final stage in LeadStage.values)
          if (stage != LeadStage.lost)
            LeadStageConfig(
              stage: stage,
              enabled: true,
              autoAdvanceDays: switch (stage) {
                LeadStage.newEnquiry => 3,
                LeadStage.contacted => 5,
                LeadStage.schoolVisit => 7,
                _ => null,
              },
            ),
      ],
      leadScores: const [
        LeadScoreConfig(
            score: LeadScore.hot, minEngagement: 80, followUpHours: 4),
        LeadScoreConfig(
            score: LeadScore.warm, minEngagement: 50, followUpHours: 24),
        LeadScoreConfig(
            score: LeadScore.cold, minEngagement: 20, followUpHours: 72),
      ],
      workflowSteps: const [
        ApplicationWorkflowConfig(
          status: ApplicationStatus.draft,
          enabled: true,
          requiresPrincipalApproval: false,
        ),
        ApplicationWorkflowConfig(
          status: ApplicationStatus.submitted,
          enabled: true,
          requiresPrincipalApproval: false,
        ),
        ApplicationWorkflowConfig(
          status: ApplicationStatus.documentsPending,
          enabled: true,
          requiresPrincipalApproval: false,
        ),
        ApplicationWorkflowConfig(
          status: ApplicationStatus.underReview,
          enabled: true,
          requiresPrincipalApproval: true,
        ),
        ApplicationWorkflowConfig(
          status: ApplicationStatus.approved,
          enabled: true,
          requiresPrincipalApproval: false,
        ),
      ],
      assignmentRules: const [
        CounselorAssignmentRule(
          id: 'rule_1',
          label: 'Round-robin by class band',
          strategy: 'Round-robin · Primary vs Secondary',
          enabled: true,
        ),
        CounselorAssignmentRule(
          id: 'rule_2',
          label: 'Walk-in desk assignment',
          strategy: 'First available counselor',
          enabled: true,
        ),
        CounselorAssignmentRule(
          id: 'rule_3',
          label: 'Marketing campaign owner',
          strategy: 'Retain campaign counselor',
          enabled: false,
        ),
      ],
      notificationTemplates: const [
        NotificationTemplate(
          id: 'tpl_1',
          name: 'Visit reminder',
          channel: 'WhatsApp',
          preview: 'Reminder: School visit scheduled for {{date}} at {{time}}.',
          enabled: true,
        ),
        NotificationTemplate(
          id: 'tpl_2',
          name: 'Application received',
          channel: 'SMS',
          preview: 'We received {{student}} application. Ref: {{app_id}}.',
          enabled: true,
        ),
        NotificationTemplate(
          id: 'tpl_3',
          name: 'Admission approved',
          channel: 'Email',
          preview: 'Congratulations! {{student}} admission is approved.',
          enabled: true,
        ),
      ],
    );
  }

  bool _resolveBoolUpdate(
    Map<String, String> updates, {
    required String sectionId,
    required String itemId,
    required bool fallback,
  }) {
    final raw = updates['$sectionId:$itemId'];
    if (raw == null) return fallback;
    return raw.toLowerCase() == 'true';
  }

  int? _resolveIntUpdate(
    Map<String, String> updates, {
    required String sectionId,
    required String itemId,
    required int? fallback,
  }) {
    final raw = updates['$sectionId:$itemId'];
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  MockAdmissionsWriteStore get _store => MockAdmissionsWriteStore.instance;

  Future<void> _ensureLeads(RepositoryQuery query) async {
    _store.leads ??= List.from(await _loadAllLeads(query));
  }

  Future<void> _ensureApplications(RepositoryQuery query) async {
    _store.applications ??= List.from(await _loadAllApplications(query));
  }

  Future<void> _ensureDocuments(RepositoryQuery query) async {
    _store.documents ??= List.from((await getDocuments(query: query)).items);
  }

  Future<void> _ensureEnrollments(RepositoryQuery query) async {
    _store.enrollments ??= List.from(await _loadAllEnrollments(query));
  }

  void _syncApprovalQueueForEnrollment(PendingEnrollmentRecord record) {
    _store.approvalQueue ??= [];
    final existingIndex = _store.approvalQueue!.indexWhere(
      (item) => item.applicationId == record.applicationId,
    );
    if (existingIndex >= 0) {
      final current = _store.approvalQueue![existingIndex];
      if (current.decision == ApprovalDecision.pending) {
        _store.approvalQueue![existingIndex] = ApprovalQueueItem(
          id: current.id,
          applicationId: record.applicationId,
          studentName: record.studentName,
          classLabel: record.seekingClass,
          parentName: record.guardianName,
          counselor: current.counselor,
          submittedLabel: record.submittedAt,
          documentsComplete: current.documentsTotal,
          documentsTotal: current.documentsTotal,
          decision: ApprovalDecision.pending,
          aiScore: current.aiScore,
        );
      }
      return;
    }
    _store.approvalQueue!.insert(
      0,
      ApprovalQueueItem(
        id: _store.nextApprovalId(),
        applicationId: record.applicationId,
        studentName: record.studentName,
        classLabel: record.seekingClass,
        parentName: record.guardianName,
        counselor: 'Admissions desk',
        submittedLabel: record.submittedAt,
        documentsComplete: 6,
        documentsTotal: 6,
        decision: ApprovalDecision.pending,
        aiScore: 78,
      ),
    );
  }

  Future<void> _ensureHandoffs(RepositoryQuery query) async {
    _store.handoffs ??= List.from(await _loadAllHandoffs(query));
  }

  Future<void> _ensureApprovalQueue(RepositoryQuery query) async {
    _store.approvalQueue ??= List.from(await _loadAllApprovalQueue(query));
  }

  @override
  Future<AdmissionsLead> createLead({
    required RepositoryQuery query,
    required CreateLeadRequest request,
  }) async {
    await _ensureLeads(query);
    final lead = AdmissionsLead(
      id: _store.nextLeadId(),
      parentName: request.parentName,
      studentName: request.studentName,
      classLabel: request.classLabel,
      phone: request.phone,
      source: request.source,
      campaign: request.campaign,
      stage: LeadStage.newEnquiry,
      counselor: request.counselor.isEmpty ? 'Unassigned' : request.counselor,
      score: LeadScore.warm,
      nextFollowUpLabel: 'Schedule first call',
    );
    _store.leads!.insert(0, lead);
    _store.lastCreatedLead = lead;
    return lead;
  }

  @override
  Future<AdmissionsLead> updateLead({
    required RepositoryQuery query,
    required String leadId,
    required UpdateLeadRequest request,
  }) async {
    await _ensureLeads(query);
    final index = _store.leads!.indexWhere((lead) => lead.id == leadId);
    if (index < 0) throw StateError('Lead not found: $leadId');
    final updated = _store.copyLead(
      _store.leads![index],
      parentName: request.parentName,
      studentName: request.studentName,
      classLabel: request.classLabel,
      phone: request.phone,
      source: request.source,
      campaign: request.campaign,
    );
    _store.leads![index] = updated;
    return updated;
  }

  @override
  Future<LeadDetailData> getLeadDetail({
    required RepositoryQuery query,
    required String leadId,
  }) async {
    await _ensureLeads(query);
    final lead = _store.leads!.firstWhere(
      (item) => item.id == leadId,
      orElse: () => throw StateError('Lead not found: $leadId'),
    );
    return LeadDetailData(
      lead: lead,
      email: '${lead.parentName.split(' ').first.toLowerCase()}@email.com',
      address: '12, Lake View Colony, Hyderabad',
      createdLabel: '28 May 2026',
      lastActivityLabel: '4 Jun 2026 · 3:15 PM',
      notes:
          'Parent interested in CBSE curriculum. Prefers morning batch. Requested fee structure.',
      activities: [
        LeadActivityItem(
          id: 'act_1',
          timestampLabel: '4 Jun · 3:15 PM',
          title: 'School visit completed',
          description:
              'Campus tour with both parents. Positive feedback on labs.',
          actor: lead.counselor,
          type: LeadActivityType.visit,
        ),
        LeadActivityItem(
          id: 'act_2',
          timestampLabel: '3 Jun · 11:00 AM',
          title: 'WhatsApp brochure sent',
          description: 'Shared fee plan and curriculum PDF.',
          actor: lead.counselor,
          type: LeadActivityType.whatsapp,
        ),
        LeadActivityItem(
          id: 'act_3',
          timestampLabel: '1 Jun · 10:30 AM',
          title: 'Stage moved to ${lead.stage.label}',
          description: 'Pipeline updated after phone screening.',
          actor: lead.counselor,
          type: LeadActivityType.stageChange,
        ),
        LeadActivityItem(
          id: 'act_4',
          timestampLabel: '28 May · 4:45 PM',
          title: 'Lead created from ${lead.source.label}',
          description: 'Campaign: ${lead.campaign}',
          actor: 'System',
          type: LeadActivityType.note,
        ),
      ],
      followUpHistory: [
        LeadFollowUpRecord(
          id: 'fh_1',
          scheduledLabel: '5 Jun · 10:00 AM',
          completedLabel: '—',
          task: 'Discuss fee plan and transport options',
          counselor: lead.counselor,
          status: FollowUpStatus.pending,
          outcome: 'Scheduled',
        ),
        LeadFollowUpRecord(
          id: 'fh_2',
          scheduledLabel: '3 Jun · 11:00 AM',
          completedLabel: '3 Jun · 11:20 AM',
          task: 'Post-visit follow-up call',
          counselor: lead.counselor,
          status: FollowUpStatus.completed,
          outcome: 'Parent requested application form',
        ),
        LeadFollowUpRecord(
          id: 'fh_3',
          scheduledLabel: '30 May · 2:00 PM',
          completedLabel: '30 May · 2:10 PM',
          task: 'Initial counselling call',
          counselor: lead.counselor,
          status: FollowUpStatus.completed,
          outcome: 'Visit scheduled for 4 Jun',
        ),
      ],
    );
  }

  @override
  Future<AdmissionsLead> assignCounselor({
    required RepositoryQuery query,
    required String leadId,
    required AssignCounselorRequest request,
  }) async {
    await _ensureLeads(query);
    final index = _store.leads!.indexWhere((lead) => lead.id == leadId);
    if (index < 0) throw StateError('Lead not found: $leadId');
    final updated = _store.copyLead(
      _store.leads![index],
      counselor: request.counselor,
    );
    _store.leads![index] = updated;
    return updated;
  }

  @override
  Future<AdmissionsLead> changeLeadStage({
    required RepositoryQuery query,
    required String leadId,
    required ChangeLeadStageRequest request,
  }) async {
    await _ensureLeads(query);
    final index = _store.leads!.indexWhere((lead) => lead.id == leadId);
    if (index < 0) throw StateError('Lead not found: $leadId');
    final updated = _store.copyLead(
      _store.leads![index],
      stage: request.stage,
    );
    _store.leads![index] = updated;
    return updated;
  }

  @override
  Future<LeadFollowUpRecord> addLeadFollowUp({
    required RepositoryQuery query,
    required String leadId,
    required FollowUpRequest request,
  }) async {
    await _ensureLeads(query);
    return LeadFollowUpRecord(
      id: 'FU-${DateTime.now().millisecondsSinceEpoch}',
      scheduledLabel: request.scheduledLabel,
      completedLabel: '',
      task: request.task,
      counselor: request.counselor,
      status: FollowUpStatus.pending,
      outcome: request.outcome,
    );
  }

  @override
  Future<LeadActivityItem> addLeadNote({
    required RepositoryQuery query,
    required String leadId,
    required LeadNoteRequest request,
  }) async {
    return LeadActivityItem(
      id: 'ACT-${DateTime.now().millisecondsSinceEpoch}',
      timestampLabel: 'Just now',
      title: 'Note added',
      description: request.content,
      actor: 'Counselor',
      type: LeadActivityType.note,
    );
  }

  @override
  Future<AdmissionsApplication> createApplication({
    required RepositoryQuery query,
    required CreateApplicationRequest request,
  }) async {
    await _ensureApplications(query);
    final app = AdmissionsApplication(
      id: _store.nextAppId(),
      studentName: request.studentName,
      classLabel: request.classLabel,
      parentName: request.parentName,
      submittedLabel: 'Draft',
      status: ApplicationStatus.draft,
      documentsComplete: 0,
      documentsTotal: 6,
      counselor: request.counselor,
    );
    _store.applications!.insert(0, app);
    if (request.leadId != null && request.leadId!.isNotEmpty) {
      _store.applicationLeadIds[app.id] = request.leadId!;
    }
    return app;
  }

  @override
  Future<AdmissionsApplication> updateApplication({
    required RepositoryQuery query,
    required String applicationId,
    required UpdateApplicationRequest request,
  }) async {
    await _ensureApplications(query);
    final index =
        _store.applications!.indexWhere((app) => app.id == applicationId);
    if (index < 0) throw StateError('Application not found: $applicationId');
    final updated = _store.copyApplication(
      _store.applications![index],
      studentName: request.studentName,
      classLabel: request.classLabel,
      parentName: request.parentName,
      counselor: request.counselor,
    );
    _store.applications![index] = updated;
    return updated;
  }

  @override
  Future<AdmissionsApplication> submitApplication({
    required RepositoryQuery query,
    required String applicationId,
  }) async {
    await _ensureApplications(query);
    final index =
        _store.applications!.indexWhere((app) => app.id == applicationId);
    if (index < 0) throw StateError('Application not found: $applicationId');
    final updated = _store.copyApplication(
      _store.applications![index],
      status: ApplicationStatus.submitted,
      submittedLabel: 'Submitted today',
    );
    _store.applications![index] = updated;
    return updated;
  }

  @override
  Future<PendingEnrollmentRecord> submitEnrollment({
    required RepositoryQuery query,
    required EnrollmentSubmitRequest request,
  }) async {
    await _ensureEnrollments(query);
    final enrollmentId = _store.nextEnrollId();
    final suffix = enrollmentId.replaceAll('enr_', '').padLeft(4, '0');
    final admissionNumber = 'ADM-2026-$suffix';
    final applicationId = request.applicationId ?? 'APP-2208';
    final record = PendingEnrollmentRecord(
      id: enrollmentId,
      studentName: request.student.fullName,
      applicationId: applicationId,
      seekingClass: request.academic.seekingClass,
      section: request.academic.section,
      academicYear: request.academic.academicYear,
      guardianName: request.parent.guardianName,
      phone: request.parent.phone,
      submittedAt: 'Just now',
      conversionStatus: EnrollmentConversionStatus.pending,
      generatedAdmissionNumber: admissionNumber,
      gender: request.student.gender,
      dateOfBirth: request.student.dateOfBirth,
    );
    _store.enrollments!.insert(0, record);
    _syncApprovalQueueForEnrollment(record);
    MockAdmissionsSisBridge.syncEnrollmentToConversionQueue(record);
    return record;
  }

  @override
  Future<GeneratedAdmissionNumber> generateAdmissionNumber({
    required RepositoryQuery query,
    required GenerateAdmissionNumberRequest request,
  }) async {
    return GeneratedAdmissionNumber(
      admissionNumber:
          'ADM-2026-${DateTime.now().millisecondsSinceEpoch % 10000}',
    );
  }

  @override
  Future<StudentDocumentRecord> uploadDocument({
    required RepositoryQuery query,
    required DocumentUploadRequest request,
  }) async {
    await _ensureDocuments(query);
    final doc = StudentDocumentRecord(
      id: _store.nextDocId(),
      studentName: request.studentName,
      classLabel: request.classLabel,
      documentType: request.documentType,
      isRequired: true,
      status: DocumentVerificationStatus.uploaded,
      uploadedLabel: 'Just now',
      verifiedBy: null,
      leadId: request.leadId,
    );
    _store.documents!.insert(0, doc);
    return doc;
  }

  @override
  Future<StudentDocumentRecord> approveDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  }) async {
    await _ensureDocuments(query);
    return _updateDocumentStatus(
      documentId,
      DocumentVerificationStatus.verified,
      verifiedBy: 'Verifier',
    );
  }

  @override
  Future<StudentDocumentRecord> rejectDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  }) async {
    await _ensureDocuments(query);
    return _updateDocumentStatus(
      documentId,
      DocumentVerificationStatus.rejected,
      verifiedBy: 'Verifier',
    );
  }

  StudentDocumentRecord _updateDocumentStatus(
    String documentId,
    DocumentVerificationStatus status, {
    required String verifiedBy,
  }) {
    final index = _store.documents!.indexWhere((doc) => doc.id == documentId);
    if (index < 0) throw StateError('Document not found: $documentId');
    final current = _store.documents![index];
    final updated = StudentDocumentRecord(
      id: current.id,
      studentName: current.studentName,
      classLabel: current.classLabel,
      documentType: current.documentType,
      isRequired: current.isRequired,
      status: status,
      uploadedLabel: current.uploadedLabel,
      verifiedBy: verifiedBy,
      leadId: current.leadId,
    );
    _store.documents![index] = updated;
    return updated;
  }

  @override
  Future<ApprovalQueueItem> approveAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  }) async {
    await _ensureApprovalQueue(query);
    return _updateApprovalDecision(approvalId, ApprovalDecision.approved);
  }

  @override
  Future<ApprovalQueueItem> rejectAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  }) async {
    await _ensureApprovalQueue(query);
    return _updateApprovalDecision(approvalId, ApprovalDecision.rejected);
  }

  ApprovalQueueItem _updateApprovalDecision(
    String approvalId,
    ApprovalDecision decision,
  ) {
    final index =
        _store.approvalQueue!.indexWhere((item) => item.id == approvalId);
    if (index < 0) throw StateError('Approval not found: $approvalId');
    final current = _store.approvalQueue![index];
    final updated = ApprovalQueueItem(
      id: current.id,
      applicationId: current.applicationId,
      studentName: current.studentName,
      classLabel: current.classLabel,
      parentName: current.parentName,
      counselor: current.counselor,
      submittedLabel: current.submittedLabel,
      documentsComplete: current.documentsComplete,
      documentsTotal: current.documentsTotal,
      decision: decision,
      aiScore: current.aiScore,
    );
    _store.approvalQueue![index] = updated;
    if (decision == ApprovalDecision.approved) {
      _syncHandoffForApprovedAdmission(updated);
    }
    return updated;
  }

  void _syncHandoffForApprovedAdmission(ApprovalQueueItem item) {
    _store.handoffs ??= [];
    final enrollment = _store.findEnrollmentByApplication(item.applicationId);
    final admissionNumber = enrollment?.generatedAdmissionNumber ??
        'ADM-2026-${item.applicationId.replaceAll('APP-', '')}';
    final previewStudentId = enrollment != null
        ? 'SIS-STU-104${enrollment.id.replaceAll('enr_', '').padLeft(2, '0')}'
        : 'SIS-STU-PENDING';
    final existingIndex = _store.handoffs!.indexWhere(
      (handoff) => handoff.applicationId == item.applicationId,
    );
    if (existingIndex >= 0) {
      final current = _store.handoffs![existingIndex];
      if (current.handoffStatus == FeeHandoffStatus.completed) return;
      _store.handoffs![existingIndex] = ApprovedStudentHandoff(
        id: current.id,
        studentName: item.studentName,
        classLabel: item.classLabel,
        applicationId: item.applicationId,
        admissionNumber: admissionNumber,
        needsTransport: current.needsTransport,
        needsHostel: current.needsHostel,
        selectedFeeStructureId: current.selectedFeeStructureId,
        handoffStatus: FeeHandoffStatus.pending,
        previewStudentId: previewStudentId,
        sisHandoffLabel: 'Ready for fee setup',
      );
      return;
    }
    _store.handoffs!.insert(
      0,
      ApprovedStudentHandoff(
        id: _store.nextHandoffId(),
        studentName: item.studentName,
        classLabel: item.classLabel,
        applicationId: item.applicationId,
        admissionNumber: admissionNumber,
        needsTransport: false,
        needsHostel: false,
        selectedFeeStructureId: 'fee_std',
        handoffStatus: FeeHandoffStatus.pending,
        previewStudentId: previewStudentId,
        sisHandoffLabel: 'Ready for fee setup',
      ),
    );
  }

  @override
  Future<CounselorNote> addApprovalNote({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalNoteRequest request,
  }) async {
    return CounselorNote(
      id: 'NOTE-${DateTime.now().millisecondsSinceEpoch}',
      author: 'Principal',
      timestampLabel: 'Just now',
      content: request.content,
    );
  }

  @override
  Future<ApprovedStudentHandoff> sendToFinance({
    required RepositoryQuery query,
    required FinanceHandoffRequest request,
  }) async {
    await _ensureHandoffs(query);
    final index =
        _store.handoffs!.indexWhere((item) => item.id == request.handoffId);
    if (index < 0) throw StateError('Handoff not found: ${request.handoffId}');
    final current = _store.handoffs![index];
    final updated = ApprovedStudentHandoff(
      id: current.id,
      studentName: current.studentName,
      classLabel: current.classLabel,
      applicationId: current.applicationId,
      admissionNumber: current.admissionNumber,
      needsTransport: current.needsTransport,
      needsHostel: current.needsHostel,
      selectedFeeStructureId: request.feeStructureId,
      handoffStatus: FeeHandoffStatus.sentToFinance,
      previewStudentId: current.previewStudentId,
      sisHandoffLabel: 'Sent to Finance',
    );
    _store.handoffs![index] = updated;
    return updated;
  }

  @override
  Future<ApprovedStudentHandoff> updateHandoffStatus({
    required RepositoryQuery query,
    required String handoffId,
    required UpdateHandoffStatusRequest request,
  }) async {
    await _ensureHandoffs(query);
    final index = _store.handoffs!.indexWhere((item) => item.id == handoffId);
    if (index < 0) throw StateError('Handoff not found: $handoffId');
    final current = _store.handoffs![index];
    final updated = ApprovedStudentHandoff(
      id: current.id,
      studentName: current.studentName,
      classLabel: current.classLabel,
      applicationId: current.applicationId,
      admissionNumber: current.admissionNumber,
      needsTransport: current.needsTransport,
      needsHostel: current.needsHostel,
      selectedFeeStructureId: current.selectedFeeStructureId,
      handoffStatus: request.status,
      previewStudentId: current.previewStudentId,
      sisHandoffLabel: current.sisHandoffLabel,
    );
    _store.handoffs![index] = updated;
    return updated;
  }
}
