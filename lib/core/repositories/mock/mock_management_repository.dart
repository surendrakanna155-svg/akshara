import 'package:flutter/material.dart';

import '../../../features/management/management_models.dart';
import '../../../features/management/management_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/management_repository.dart';
import '../repository_query.dart';

/// Executive management mock data aligned with Admissions, Finance, and SIS MVPs.
class MockManagementRepository implements ManagementRepository {
  MockManagementRepository()
      : _approvals = List<ManagementApprovalItem>.from(_seedApprovals);

  final List<ManagementApprovalItem> _approvals;

  static const _recentConversions = [
    ManagementRecentConversion(
      id: 'conv_1',
      leadName: 'Ananya Reddy',
      classLabel: '5',
      source: 'Walk-in',
      counselor: 'Meera N.',
      stage: 'Confirmed',
      daysInPipeline: 18,
    ),
    ManagementRecentConversion(
      id: 'conv_2',
      leadName: 'Arjun Patel',
      classLabel: '10',
      source: 'Referral',
      counselor: 'Sneha K.',
      stage: 'Joined',
      daysInPipeline: 24,
    ),
    ManagementRecentConversion(
      id: 'conv_3',
      leadName: 'Emma Thomas',
      classLabel: '7',
      source: 'Walk-in',
      counselor: 'Sneha K.',
      stage: 'Joined',
      daysInPipeline: 21,
    ),
    ManagementRecentConversion(
      id: 'conv_4',
      leadName: 'Karthik Sharma',
      classLabel: '8',
      source: 'Website',
      counselor: 'Rahul V.',
      stage: 'Demo class',
      daysInPipeline: 12,
    ),
  ];

  static const _seedApprovals = [
    ManagementApprovalItem(
      id: 'appr_mg_1',
      type: ManagementApprovalType.budget,
      title: 'Science lab upgrade — Q3 budget',
      requester: 'Finance Manager',
      amount: '₹8.5L',
      dateLabel: 'Today',
      status: ManagementApprovalStatus.pending,
      aiRecommendation: ManagementAiRecommendation.approve,
      sourceModuleRoute: RouteNames.financeReports,
    ),
    ManagementApprovalItem(
      id: 'appr_mg_2',
      type: ManagementApprovalType.expense,
      title: 'Marketing campaign — Summer Open Day',
      requester: 'Admissions Head',
      amount: '₹2.2L',
      dateLabel: 'Yesterday',
      status: ManagementApprovalStatus.pending,
      aiRecommendation: ManagementAiRecommendation.review,
      sourceModuleRoute: RouteNames.admissionsReports,
    ),
    ManagementApprovalItem(
      id: 'appr_mg_3',
      type: ManagementApprovalType.payroll,
      title: 'June 2026 payroll batch',
      requester: 'Finance Manager',
      amount: '₹42.0L',
      dateLabel: 'Yesterday',
      status: ManagementApprovalStatus.pending,
      aiRecommendation: ManagementAiRecommendation.approve,
      sourceModuleRoute: RouteNames.financeDashboard,
    ),
    ManagementApprovalItem(
      id: 'appr_mg_4',
      type: ManagementApprovalType.vendor,
      title: 'Smart board vendor — Phase 2',
      requester: 'IT Admin',
      amount: '₹6.8L',
      dateLabel: '2 days ago',
      status: ManagementApprovalStatus.pending,
      aiRecommendation: ManagementAiRecommendation.review,
      sourceModuleRoute: RouteNames.financeCollections,
    ),
    ManagementApprovalItem(
      id: 'appr_mg_5',
      type: ManagementApprovalType.admission,
      title: 'Ananya Reddy — Class 5 admission',
      requester: 'Meera N.',
      amount: '—',
      dateLabel: '4 Jun 2026',
      status: ManagementApprovalStatus.pending,
      aiRecommendation: ManagementAiRecommendation.approve,
      sourceModuleRoute: RouteNames.admissionsApproval,
    ),
    ManagementApprovalItem(
      id: 'appr_mg_6',
      type: ManagementApprovalType.marketing,
      title: 'Digital ads — Q3 enrollment',
      requester: 'Marketing Lead',
      amount: '₹1.5L',
      dateLabel: '3 days ago',
      status: ManagementApprovalStatus.approved,
      aiRecommendation: ManagementAiRecommendation.approve,
      sourceModuleRoute: RouteNames.admissionsDashboard,
    ),
    ManagementApprovalItem(
      id: 'appr_mg_7',
      type: ManagementApprovalType.expense,
      title: 'Sports day logistics',
      requester: 'Activities Head',
      amount: '₹85K',
      dateLabel: '4 days ago',
      status: ManagementApprovalStatus.rejected,
      aiRecommendation: ManagementAiRecommendation.reject,
      sourceModuleRoute: RouteNames.financeRefunds,
    ),
  ];

  @override
  Future<ManagementDashboardData> getDashboard({required RepositoryQuery query}) async {
    return ManagementDashboardData(
      kpis: const [
        ManagementKpi(
          id: 'revenue_mtd',
          value: '₹1.2Cr',
          label: 'Revenue (MTD)',
          icon: Icons.trending_up,
          accentName: 'success',
          detail: '+9% vs last month',
          drillRoute: RouteNames.financeReports,
        ),
        ManagementKpi(
          id: 'fee_collection',
          value: '68%',
          label: 'Fee Collection %',
          icon: Icons.payments_outlined,
          accentName: 'warning',
        ),
        ManagementKpi(
          id: 'fee_defaulters',
          value: '47',
          label: 'Fee Defaulters',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
          detail: 'Collection follow-up',
          drillRoute: RouteNames.financeDefaulters,
        ),
        ManagementKpi(
          id: 'net_margin',
          value: '31.6%',
          label: 'Net Margin',
          icon: Icons.savings_outlined,
          accentName: 'success',
        ),
        ManagementKpi(
          id: 'new_admissions',
          value: '42',
          label: 'New Admissions (QTD)',
          icon: Icons.person_add_outlined,
          accentName: 'primary',
          drillRoute: RouteNames.managementAdmissions,
        ),
        ManagementKpi(
          id: 'pending_approvals',
          value: '7',
          label: 'Pending Approvals',
          icon: Icons.pending_actions_outlined,
          accentName: 'error',
        ),
      ],
      revenueTrend: const [
        ManagementTrendPoint(label: 'Jul', amountLakhs: 8.2, targetLakhs: 9.0),
        ManagementTrendPoint(label: 'Aug', amountLakhs: 9.1, targetLakhs: 9.0),
        ManagementTrendPoint(label: 'Sep', amountLakhs: 10.4, targetLakhs: 10.0),
        ManagementTrendPoint(label: 'Oct', amountLakhs: 11.0, targetLakhs: 10.5),
        ManagementTrendPoint(label: 'Nov', amountLakhs: 11.8, targetLakhs: 11.0),
        ManagementTrendPoint(label: 'Dec', amountLakhs: 12.2, targetLakhs: 11.5),
        ManagementTrendPoint(label: 'Jan', amountLakhs: 10.5, targetLakhs: 11.0),
        ManagementTrendPoint(label: 'Feb', amountLakhs: 11.2, targetLakhs: 11.0),
        ManagementTrendPoint(label: 'Mar', amountLakhs: 11.8, targetLakhs: 11.5),
        ManagementTrendPoint(label: 'Apr', amountLakhs: 12.4, targetLakhs: 12.0),
        ManagementTrendPoint(label: 'May', amountLakhs: 12.8, targetLakhs: 12.0),
        ManagementTrendPoint(label: 'Jun', amountLakhs: 12.0, targetLakhs: 12.5),
      ],
      expenseBreakdown: const [
        ManagementSegment(label: 'Salaries', value: 22, percent: 48),
        ManagementSegment(label: 'Utilities', value: 6, percent: 13),
        ManagementSegment(label: 'Marketing', value: 5, percent: 11),
        ManagementSegment(label: 'Transport', value: 4, percent: 9),
        ManagementSegment(label: 'Supplies', value: 9, percent: 19),
      ],
      approvalQueue: _approvals
          .where((a) => a.status == ManagementApprovalStatus.pending)
          .take(4)
          .toList(growable: false),
      admissionsSnapshot: const ManagementAdmissionsSnapshot(
        leadsMtd: 248,
        confirmed: 42,
        joined: 36,
        conversionRate: '14.5%',
        recentConversions: _recentConversions,
      ),
      feeSnapshot: const ManagementFeeSnapshot(
        collectedMtd: '₹42.0L',
        outstanding: '₹18.6L',
        collectionRate: '68%',
        defaulters: 47,
      ),
      aiInsight:
          'Fee collection dipped 4% in Class 8 while admissions conversion holds at 14.5%. 7 approvals pending — prioritize payroll and Q3 lab budget before month-end.',
    );
  }

  @override
  Future<ManagementAnalyticsData> getAnalytics({required RepositoryQuery query}) async {
    return const ManagementAnalyticsData(
      kpis: [
        ManagementKpi(
          id: 'students',
          value: '1,248',
          label: 'Total Students',
          icon: Icons.groups_outlined,
          accentName: 'primary',
        ),
        ManagementKpi(
          id: 'attendance',
          value: '94.2%',
          label: 'Attendance (MTD)',
          icon: Icons.fact_check_outlined,
          accentName: 'success',
          drillRoute: RouteNames.studentSuccessIntelligence,
        ),
        ManagementKpi(
          id: 'staff',
          value: '186',
          label: 'Staff Strength',
          icon: Icons.badge_outlined,
          accentName: 'neutral',
        ),
        ManagementKpi(
          id: 'pass_rate',
          value: '89.4%',
          label: 'Pass Rate',
          icon: Icons.school_outlined,
          accentName: 'success',
        ),
      ],
      enrollmentTrend: [
        ManagementTrendPoint(label: '2024', amountLakhs: 11.2, targetLakhs: 11.0),
        ManagementTrendPoint(label: '2025', amountLakhs: 11.8, targetLakhs: 11.5),
        ManagementTrendPoint(label: '2026', amountLakhs: 12.4, targetLakhs: 12.0),
      ],
      attendanceByClass: [
        ManagementSegment(label: 'Primary', value: 95, percent: 95),
        ManagementSegment(label: 'Middle', value: 94, percent: 94),
        ManagementSegment(label: 'Secondary', value: 93, percent: 93),
        ManagementSegment(label: 'Senior', value: 92, percent: 92),
      ],
      classSummary: [
        ManagementClassSummaryRow(
          classLabel: '10-A',
          students: 42,
          attendancePercent: '96%',
          avgMarks: '78%',
          feeCollectionPercent: '72%',
          teachers: 8,
        ),
        ManagementClassSummaryRow(
          classLabel: '8-B',
          students: 38,
          attendancePercent: '91%',
          avgMarks: '74%',
          feeCollectionPercent: '58%',
          teachers: 7,
        ),
        ManagementClassSummaryRow(
          classLabel: '5-A',
          students: 36,
          attendancePercent: '95%',
          avgMarks: '81%',
          feeCollectionPercent: '64%',
          teachers: 6,
        ),
      ],
      aiInsight:
          'Class 8-B shows lowest fee collection (58%) and attendance (91%). Correlate with defaulter spike in Finance FN-07.',
    );
  }

  @override
  Future<ManagementAdmissionsFunnelData> getAdmissionsFunnel({required RepositoryQuery query}) async {
    return const ManagementAdmissionsFunnelData(
      kpis: [
        ManagementKpi(
          id: 'leads',
          value: '248',
          label: 'Leads (MTD)',
          icon: Icons.people_outline,
          accentName: 'primary',
        ),
        ManagementKpi(
          id: 'conversion',
          value: '14.5%',
          label: 'Conversion Rate',
          icon: Icons.trending_up,
          accentName: 'success',
        ),
        ManagementKpi(
          id: 'confirmed',
          value: '42',
          label: 'Confirmed',
          icon: Icons.verified_outlined,
          accentName: 'primary',
        ),
        ManagementKpi(
          id: 'joined',
          value: '36',
          label: 'Joined',
          icon: Icons.school_outlined,
          accentName: 'success',
        ),
      ],
      funnelStages: [
        ManagementFunnelStage(label: 'Enquiries', count: 312, percent: 100),
        ManagementFunnelStage(label: 'Qualified', count: 248, percent: 79.5),
        ManagementFunnelStage(label: 'Visits', count: 96, percent: 30.8),
        ManagementFunnelStage(label: 'Confirmed', count: 42, percent: 13.5),
        ManagementFunnelStage(label: 'Joined', count: 36, percent: 11.5),
      ],
      sourcePerformance: [
        ManagementSegment(label: 'Walk-in', value: 82, percent: 33),
        ManagementSegment(label: 'Website', value: 58, percent: 23),
        ManagementSegment(label: 'WhatsApp', value: 44, percent: 18),
        ManagementSegment(label: 'Referral', value: 36, percent: 15),
      ],
      recentConversions: _recentConversions,
      admissionsReportsRoute: RouteNames.admissionsReports,
      aiInsight:
          'Conversion drops 18% after Demo Class. Recommend same-day follow-up — drill to AD-09 Reports for counselor breakdown.',
    );
  }

  @override
  Future<ManagementFinancialHealthData> getFinancialHealth({required RepositoryQuery query}) async {
    return const ManagementFinancialHealthData(
      revenue: '₹1.2Cr',
      expenses: '₹46L',
      netProfit: '₹74L',
      kpis: [
        ManagementKpi(
          id: 'collection',
          value: '₹42.0L',
          label: 'Fee Collected (MTD)',
          icon: Icons.payments_outlined,
          accentName: 'success',
        ),
        ManagementKpi(
          id: 'outstanding',
          value: '₹18.6L',
          label: 'Outstanding',
          icon: Icons.pending_actions_outlined,
          accentName: 'warning',
        ),
        ManagementKpi(
          id: 'payroll',
          value: '₹42.0L',
          label: 'Payroll (Jun)',
          icon: Icons.badge_outlined,
          accentName: 'neutral',
        ),
        ManagementKpi(
          id: 'cash',
          value: '₹28L',
          label: 'Cash Balance',
          icon: Icons.account_balance_outlined,
          accentName: 'primary',
        ),
      ],
      plTrend: [
        ManagementTrendPoint(label: 'Q1', amountLakhs: 32, targetLakhs: 30),
        ManagementTrendPoint(label: 'Q2', amountLakhs: 35, targetLakhs: 33),
        ManagementTrendPoint(label: 'Q3', amountLakhs: 38, targetLakhs: 36),
        ManagementTrendPoint(label: 'Q4', amountLakhs: 40, targetLakhs: 38),
      ],
      cashFlowTrend: [
        ManagementTrendPoint(label: 'Apr', amountLakhs: 8.2, targetLakhs: 8.0),
        ManagementTrendPoint(label: 'May', amountLakhs: 9.5, targetLakhs: 8.5),
        ManagementTrendPoint(label: 'Jun', amountLakhs: 10.2, targetLakhs: 9.0),
      ],
      drillLinks: [
        ManagementFinanceDrillLink(
          id: 'fn_dashboard',
          title: 'Finance Dashboard',
          subtitle: 'Operational KPIs',
          route: RouteNames.financeDashboard,
          metric: '₹42.0L MTD',
        ),
        ManagementFinanceDrillLink(
          id: 'fn_defaulters',
          title: 'Defaulters',
          subtitle: '47 students overdue',
          route: RouteNames.financeDefaulters,
          metric: '₹18.6L',
        ),
        ManagementFinanceDrillLink(
          id: 'fn_collections',
          title: 'Collections',
          subtitle: 'Daily receipts',
          route: RouteNames.financeCollections,
          metric: '18 txns today',
        ),
        ManagementFinanceDrillLink(
          id: 'fn_reports',
          title: 'Finance Reports',
          subtitle: 'P&L and cash flow',
          route: RouteNames.financeReports,
          metric: '4 reports',
        ),
        ManagementFinanceDrillLink(
          id: 'fn_accounts',
          title: 'Student Accounts',
          subtitle: 'Fee balances',
          route: RouteNames.financeStudentAccounts,
          metric: '4 active',
        ),
        ManagementFinanceDrillLink(
          id: 'fn_settings',
          title: 'Finance Settings',
          subtitle: 'Policies & gateways',
          route: RouteNames.financeSettings,
          metric: '2026-27',
        ),
      ],
      aiInsight:
          'Read-only executive view. Drill to Finance module for transactions. Outstanding fees correlate with 47 defaulters in FN-07.',
    );
  }

  @override
  Future<ManagementAcademicHealthData> getAcademicHealth({required RepositoryQuery query}) async {
    return const ManagementAcademicHealthData(
      kpis: [
        ManagementKpi(
          id: 'pass_rate',
          value: '89.4%',
          label: 'Overall Pass %',
          icon: Icons.school_outlined,
          accentName: 'success',
          drillRoute: RouteNames.examIntelligence,
        ),
        ManagementKpi(
          id: 'distinction',
          value: '34%',
          label: 'Distinction %',
          icon: Icons.emoji_events_outlined,
          accentName: 'primary',
        ),
        ManagementKpi(
          id: 'at_risk',
          value: '28',
          label: 'At-risk Students',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
          drillRoute: RouteNames.examIntelligence,
        ),
        ManagementKpi(
          id: 'teacher_attendance',
          value: '97%',
          label: 'Teacher Attendance',
          icon: Icons.fact_check_outlined,
          accentName: 'success',
        ),
      ],
      metrics: [
        ManagementAcademicMetric(
          id: 'homework',
          label: 'Homework completion',
          value: '86%',
          trend: '+2%',
          accentName: 'success',
        ),
        ManagementAcademicMetric(
          id: 'exam_avg',
          label: 'Term exam average',
          value: '74%',
          trend: '-1%',
          accentName: 'warning',
        ),
        ManagementAcademicMetric(
          id: 'parent_eng',
          label: 'Parent engagement',
          value: '78%',
          trend: '+5%',
          accentName: 'primary',
        ),
      ],
      subjectPerformance: [
        ManagementSubjectPerformance(
          subject: 'Mathematics',
          passPercent: '82%',
          avgScore: '71%',
          atRiskCount: 12,
        ),
        ManagementSubjectPerformance(
          subject: 'Science',
          passPercent: '88%',
          avgScore: '76%',
          atRiskCount: 8,
        ),
        ManagementSubjectPerformance(
          subject: 'English',
          passPercent: '91%',
          avgScore: '79%',
          atRiskCount: 5,
        ),
      ],
      atRiskStudents: [
        'Priya Sharma — Class 8-B (fee + attendance)',
        'Rohan Mehta — Class 9-A (marks below 50%)',
        'Kavya Iyer — Class 6-C (pending SIS enrollment)',
      ],
      aiInsight:
          '28 at-risk students flagged. Class 8-B overlaps with Finance defaulters and low attendance in MG-02 analytics.',
    );
  }

  @override
  Future<ManagementPerformanceData> getSchoolPerformance({required RepositoryQuery query}) async {
    return const ManagementPerformanceData(
      kpis: [
        ManagementKpi(
          id: 'pass',
          value: '89.4%',
          label: 'Pass Rate',
          icon: Icons.school_outlined,
          accentName: 'success',
        ),
        ManagementKpi(
          id: 'distinction',
          value: '34%',
          label: 'Distinction %',
          icon: Icons.star_outline,
          accentName: 'primary',
        ),
        ManagementKpi(
          id: 'at_risk',
          value: '28',
          label: 'At-risk Students',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
          drillRoute: RouteNames.examIntelligence,
        ),
        ManagementKpi(
          id: 'teacher_avg',
          value: '96%',
          label: 'Teacher Attendance',
          icon: Icons.groups_outlined,
          accentName: 'success',
        ),
      ],
      classPerformance: [
        ManagementClassPerformanceRow(
          classLabel: '10-A',
          students: 42,
          passPercent: '94%',
          avgMarks: '78%',
          attendance: '96%',
          disciplineScore: 'A',
          rank: 1,
        ),
        ManagementClassPerformanceRow(
          classLabel: '8-B',
          students: 38,
          passPercent: '82%',
          avgMarks: '68%',
          attendance: '91%',
          disciplineScore: 'C',
          rank: 8,
        ),
        ManagementClassPerformanceRow(
          classLabel: '5-A',
          students: 36,
          passPercent: '91%',
          avgMarks: '81%',
          attendance: '95%',
          disciplineScore: 'B',
          rank: 3,
        ),
      ],
      atRiskStudents: [
        'Priya Sharma — Class 8-B',
        'Rohan Mehta — Class 9-A',
        'Ananya Reddy — Class 5-A (pending fees)',
      ],
      aiInsight:
          'Class 8-B ranks lowest on discipline and pass rate. Align interventions with MG-05 academic health and FN-07 defaulters.',
    );
  }

  @override
  Future<ManagementTasksData> getTasksAndApprovals({required RepositoryQuery query}) async {
    return ManagementTasksData(
      kpis: const [
        ManagementKpi(
          id: 'pending',
          value: '7',
          label: 'Pending',
          icon: Icons.pending_actions_outlined,
          accentName: 'warning',
        ),
        ManagementKpi(
          id: 'approved_today',
          value: '3',
          label: 'Approved Today',
          icon: Icons.check_circle_outline,
          accentName: 'success',
        ),
        ManagementKpi(
          id: 'rejected',
          value: '1',
          label: 'Rejected (week)',
          icon: Icons.cancel_outlined,
          accentName: 'error',
        ),
        ManagementKpi(
          id: 'avg_time',
          value: '1.8d',
          label: 'Avg Approval Time',
          icon: Icons.schedule_outlined,
          accentName: 'neutral',
        ),
      ],
      approvals: List<ManagementApprovalItem>.from(_approvals),
      aiInsight:
          'AI recommends approving payroll and Class 5 admission. Review vendor payment — amount exceeds ₹50K threshold.',
    );
  }

  @override
  Future<ManagementSettingsData> getSettings({required RepositoryQuery query}) async {
    return const ManagementSettingsData(
      academicYear: '2026-27',
      sections: [
        ManagementSettingsSection(
          id: 'school',
          title: 'School profile',
          items: [
            ManagementSettingItem(
              id: 'name',
              label: 'School name',
              value: 'Akshara International School',
              description: 'Displayed on reports and parent app',
              editable: true,
            ),
            ManagementSettingItem(
              id: 'campus',
              label: 'Primary campus',
              value: 'Hyderabad — Main',
              description: 'Single-campus MVP configuration',
              editable: false,
            ),
          ],
        ),
        ManagementSettingsSection(
          id: 'approvals',
          title: 'Approval thresholds',
          items: [
            ManagementSettingItem(
              id: 'expense',
              label: 'Expense approval threshold',
              value: '₹25,000',
              description: 'Routes to MG-07 Tasks & Approvals',
              editable: true,
            ),
            ManagementSettingItem(
              id: 'vendor',
              label: 'Vendor payment threshold',
              value: '₹50,000',
              description: 'Requires management sign-off',
              editable: true,
            ),
          ],
        ),
        ManagementSettingsSection(
          id: 'notifications',
          title: 'Executive alerts',
          items: [
            ManagementSettingItem(
              id: 'fee_alert',
              label: 'Fee collection alert',
              value: 'Below 70%',
              description: 'Links to Finance FN-07 defaulters',
              editable: true,
            ),
            ManagementSettingItem(
              id: 'admissions_alert',
              label: 'Admissions conversion alert',
              value: 'Below 12%',
              description: 'Links to Admissions AD-09 reports',
              editable: true,
            ),
          ],
        ),
        ManagementSettingsSection(
          id: 'integrations',
          title: 'Module integrations',
          items: [
            ManagementSettingItem(
              id: 'finance_embed',
              label: 'Financial health embed',
              value: 'Finance MVP (FN-01–11)',
              description: 'MG-04 drills to Finance routes',
              editable: false,
            ),
            ManagementSettingItem(
              id: 'sis_embed',
              label: 'Academic data source',
              value: 'Student SIS (SIS-01–05)',
              description: 'MG-05 uses SIS enrollment metrics',
              editable: false,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<ManagementApprovalItem> resolveManagementApproval({
    required RepositoryQuery query,
    required ResolveManagementApprovalRequest request,
  }) async {
    if (request.status == ManagementApprovalStatus.pending) {
      throw StateError('Cannot resolve approval to pending');
    }

    final index = _approvals.indexWhere((a) => a.id == request.approvalId);
    if (index < 0) {
      throw StateError('Approval not found');
    }

    final current = _approvals[index];
    if (current.status != ManagementApprovalStatus.pending) {
      throw StateError('Only pending approvals can be resolved');
    }

    final resolved = ManagementApprovalItem(
      id: current.id,
      type: current.type,
      title: current.title,
      requester: current.requester,
      amount: current.amount,
      dateLabel: current.dateLabel,
      status: request.status,
      aiRecommendation: current.aiRecommendation,
      sourceModuleRoute: current.sourceModuleRoute,
    );
    _approvals[index] = resolved;
    return resolved;
  }
}
