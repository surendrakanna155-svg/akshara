import 'package:flutter/material.dart';

import '../../../features/admissions/admissions_models.dart';
import '../interfaces/admissions_repository.dart';

/// In-memory admissions data for MVP screens.
class MockAdmissionsRepository implements AdmissionsRepository {
  @override
  AdmissionsDashboardData getDashboard() {
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
  List<AdmissionsLead> getLeads() {
    return const [
      AdmissionsLead(
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
      AdmissionsLead(
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
      AdmissionsLead(
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
      AdmissionsLead(
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
      AdmissionsLead(
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
      AdmissionsLead(
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
      AdmissionsLead(
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
  }

  @override
  List<AdmissionsApplication> getApplications() {
    return const [
      AdmissionsApplication(
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
      AdmissionsApplication(
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
      AdmissionsApplication(
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
      AdmissionsApplication(
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
      AdmissionsApplication(
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
      AdmissionsApplication(
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
  }

  @override
  List<StudentDocumentRecord> getDocuments() {
    return const [
      StudentDocumentRecord(
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
      StudentDocumentRecord(
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
      StudentDocumentRecord(
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
      StudentDocumentRecord(
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
      StudentDocumentRecord(
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
      StudentDocumentRecord(
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
  }

  @override
  List<PendingEnrollmentRecord> getPendingEnrollments() {
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
  List<ApprovedStudentHandoff> getApprovedHandoffs() {
    return const [
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
  }

  @override
  List<FeeStructureOption> getFeeStructureOptions() {
    return const [
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
    ];
  }

  @override
  List<ApprovalQueueItem> getApprovalQueue() {
    return const [
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
  }

  @override
  AdmissionsReportsData getReports() {
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
  AdmissionsSettingsData getSettings() {
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
        LeadScoreConfig(score: LeadScore.hot, minEngagement: 80, followUpHours: 4),
        LeadScoreConfig(score: LeadScore.warm, minEngagement: 50, followUpHours: 24),
        LeadScoreConfig(score: LeadScore.cold, minEngagement: 20, followUpHours: 72),
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

  @override
  EnrollmentFormState getEnrollmentPrefill() {
    return const EnrollmentFormState(
      student: EnrollmentStudentProfile(
        fullName: 'Ananya Reddy',
        dateOfBirth: '12 Mar 2016',
        gender: 'Female',
        aadhaar: 'XXXX-XXXX-4521',
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
}
