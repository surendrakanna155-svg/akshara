import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

final admissionsReportsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsReportsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsReportsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsReportsTabProvider = StateProvider<AdmissionsReportTab>(
  (ref) => AdmissionsReportTab.funnel,
);

final admissionsReportsProvider = Provider<AdmissionsReportsData?>((ref) {
  if (ref.watch(admissionsReportsLoadingProvider)) return null;
  if (ref.watch(admissionsReportsErrorProvider)) return null;
  if (ref.watch(admissionsReportsEmptyProvider)) return null;
  return _mockReports();
});

AdmissionsReportsData _mockReports() {
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
