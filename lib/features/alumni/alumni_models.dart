import 'package:flutter/material.dart';

/// Alumni sub-module destinations (AL-01 → AL-09; AL-03 is a child route).
enum AlumniScreen {
  dashboard,
  registry,
  events,
  donations,
  campaigns,
  mentorship,
  reports,
  settings;

  String get label => switch (this) {
        AlumniScreen.dashboard => 'Dashboard',
        AlumniScreen.registry => 'Registry',
        AlumniScreen.events => 'Events',
        AlumniScreen.donations => 'Donations',
        AlumniScreen.campaigns => 'Campaigns',
        AlumniScreen.mentorship => 'Mentorship',
        AlumniScreen.reports => 'Reports',
        AlumniScreen.settings => 'Settings',
      };
}

enum AlumniEngagementStatus { active, inactive, pending }

enum AlumniEventStatus { upcoming, ongoing, completed, cancelled }

enum AlumniDonationStatus { received, pledged, pending, refunded }

enum AlumniCampaignStatus { active, draft, completed, paused }

enum MentorshipStatus { active, pending, completed, onHold }

@immutable
class AlumniKpi {
  const AlumniKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class AlumniTrendPoint {
  const AlumniTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class AlumniSegment {
  const AlumniSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class AlumniRecord {
  const AlumniRecord({
    required this.id,
    required this.name,
    required this.batchYear,
    required this.program,
    required this.currentRole,
    required this.city,
    required this.email,
    required this.phone,
    required this.engagementStatus,
    required this.sisStudentId,
    required this.totalDonated,
    required this.lastEventAttended,
  });

  final String id;
  final String name;
  final String batchYear;
  final String program;
  final String currentRole;
  final String city;
  final String email;
  final String phone;
  final AlumniEngagementStatus engagementStatus;
  final String sisStudentId;
  final String totalDonated;
  final String lastEventAttended;
}

@immutable
class AlumniDonationSummary {
  const AlumniDonationSummary({
    required this.totalReceived,
    required this.pledgedAmount,
    required this.pendingAmount,
    required this.financeLedgerRoute,
  });

  final String totalReceived;
  final String pledgedAmount;
  final String pendingAmount;
  final String financeLedgerRoute;
}

@immutable
class AlumniEngagementMetrics {
  const AlumniEngagementMetrics({
    required this.activeAlumni,
    required this.eventAttendanceRate,
    required this.mentorshipPairs,
    required this.campaignParticipation,
  });

  final int activeAlumni;
  final String eventAttendanceRate;
  final int mentorshipPairs;
  final String campaignParticipation;
}

@immutable
class AlumniDashboardData {
  const AlumniDashboardData({
    required this.kpis,
    required this.recentGraduates,
    required this.upcomingEvents,
    required this.donationSummary,
    required this.engagement,
    required this.aiInsight,
  });

  final List<AlumniKpi> kpis;
  final List<AlumniRecord> recentGraduates;
  final List<AlumniEvent> upcomingEvents;
  final AlumniDonationSummary donationSummary;
  final AlumniEngagementMetrics engagement;
  final String aiInsight;
}

@immutable
class AlumniEmploymentHistory {
  const AlumniEmploymentHistory({
    required this.organization,
    required this.role,
    required this.period,
  });

  final String organization;
  final String role;
  final String period;
}

@immutable
class AlumniDonationHistoryItem {
  const AlumniDonationHistoryItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.campaign,
    required this.status,
    required this.financeReceiptId,
  });

  final String id;
  final String date;
  final String amount;
  final String campaign;
  final AlumniDonationStatus status;
  final String financeReceiptId;
}

@immutable
class AlumniDetail {
  const AlumniDetail({
    required this.alumni,
    required this.employmentHistory,
    required this.donationHistory,
    required this.mentorshipRole,
    required this.eventsAttended,
  });

  final AlumniRecord alumni;
  final List<AlumniEmploymentHistory> employmentHistory;
  final List<AlumniDonationHistoryItem> donationHistory;
  final String mentorshipRole;
  final List<String> eventsAttended;
}

@immutable
class AlumniEvent {
  const AlumniEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.venue,
    required this.registrations,
    required this.capacity,
    required this.status,
    required this.organizer,
  });

  final String id;
  final String title;
  final String date;
  final String venue;
  final int registrations;
  final int capacity;
  final AlumniEventStatus status;
  final String organizer;
}

@immutable
class AlumniDonation {
  const AlumniDonation({
    required this.id,
    required this.alumniName,
    required this.alumniId,
    required this.amount,
    required this.date,
    required this.campaign,
    required this.status,
    required this.financeReceiptId,
    required this.paymentMode,
  });

  final String id;
  final String alumniName;
  final String alumniId;
  final String amount;
  final String date;
  final String campaign;
  final AlumniDonationStatus status;
  final String financeReceiptId;
  final String paymentMode;
}

@immutable
class AlumniCampaign {
  const AlumniCampaign({
    required this.id,
    required this.name,
    required this.goalAmount,
    required this.raisedAmount,
    required this.donorCount,
    required this.deadline,
    required this.status,
    required this.financeAccountCode,
  });

  final String id;
  final String name;
  final String goalAmount;
  final String raisedAmount;
  final int donorCount;
  final String deadline;
  final AlumniCampaignStatus status;
  final String financeAccountCode;
}

@immutable
class MentorshipPair {
  const MentorshipPair({
    required this.id,
    required this.mentorName,
    required this.mentorAlumniId,
    required this.menteeName,
    required this.menteeBatch,
    required this.focusArea,
    required this.status,
    required this.sessionsCompleted,
  });

  final String id;
  final String mentorName;
  final String mentorAlumniId;
  final String menteeName;
  final String menteeBatch;
  final String focusArea;
  final MentorshipStatus status;
  final int sessionsCompleted;
}

@immutable
class AlumniReportCatalogItem {
  const AlumniReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final String lastGenerated;
}

@immutable
class AlumniReportsData {
  const AlumniReportsData({
    required this.catalog,
    required this.donationTrend,
    required this.engagementByBatch,
    required this.eventAttendanceTrend,
  });

  final List<AlumniReportCatalogItem> catalog;
  final List<AlumniTrendPoint> donationTrend;
  final List<AlumniSegment> engagementByBatch;
  final List<AlumniTrendPoint> eventAttendanceTrend;
}

@immutable
class AlumniSettingItem {
  const AlumniSettingItem({
    required this.id,
    required this.label,
    required this.value,
    required this.description,
    required this.editable,
  });

  final String id;
  final String label;
  final String value;
  final String description;
  final bool editable;
}

@immutable
class AlumniSettingsSection {
  const AlumniSettingsSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<AlumniSettingItem> items;
}

@immutable
class AlumniSettingsData {
  const AlumniSettingsData({
    required this.sections,
    required this.mobileCompanionEnabled,
  });

  final List<AlumniSettingsSection> sections;
  final bool mobileCompanionEnabled;
}
