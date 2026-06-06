import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

final admissionsDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsDashboardErrorProvider = StateProvider<bool>((ref) => false);
final admissionsDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsDashboardFilterProvider = StateProvider<int>((ref) => 0);

final admissionsDashboardProvider = Provider<AdmissionsDashboardData?>((ref) {
  if (ref.watch(admissionsDashboardLoadingProvider)) return null;
  if (ref.watch(admissionsDashboardErrorProvider)) return null;
  if (ref.watch(admissionsDashboardEmptyProvider)) return null;
  return _mockDashboard();
});

AdmissionsDashboardData _mockDashboard() {
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
