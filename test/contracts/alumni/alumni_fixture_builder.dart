import 'package:akshara_erp/core/repositories/api/alumni/dto/alumni_enum_codec.dart';
import 'package:akshara_erp/features/alumni/alumni_models.dart';

/// Builds API-shaped JSON envelopes from Alumni domain models for contract tests.
class AlumniFixtureBuilder {
  const AlumniFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> trendPoint(AlumniTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(AlumniSegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> recordItem(AlumniRecord record) => {
        'id': record.id,
        'name': record.name,
        'batchYear': record.batchYear,
        'program': record.program,
        'currentRole': record.currentRole,
        'city': record.city,
        'email': record.email,
        'phone': record.phone,
        'engagementStatus':
            AlumniEnumCodec.engagementStatusToApi(record.engagementStatus),
        'sisStudentId': record.sisStudentId,
        'totalDonated': record.totalDonated,
        'lastEventAttended': record.lastEventAttended,
      };

  Map<String, dynamic> eventItem(AlumniEvent event) => {
        'id': event.id,
        'title': event.title,
        'date': event.date,
        'venue': event.venue,
        'registrations': event.registrations,
        'capacity': event.capacity,
        'status': AlumniEnumCodec.eventStatusToApi(event.status),
        'organizer': event.organizer,
      };

  Map<String, dynamic> donationItem(AlumniDonation donation) => {
        'id': donation.id,
        'alumniName': donation.alumniName,
        'alumniId': donation.alumniId,
        'amount': donation.amount,
        'date': donation.date,
        'campaign': donation.campaign,
        'status': AlumniEnumCodec.donationStatusToApi(donation.status),
        'financeReceiptId': donation.financeReceiptId,
        'paymentMode': donation.paymentMode,
      };

  Map<String, dynamic> campaignItem(AlumniCampaign campaign) => {
        'id': campaign.id,
        'name': campaign.name,
        'goalAmount': campaign.goalAmount,
        'raisedAmount': campaign.raisedAmount,
        'donorCount': campaign.donorCount,
        'deadline': campaign.deadline,
        'status': AlumniEnumCodec.campaignStatusToApi(campaign.status),
        'financeAccountCode': campaign.financeAccountCode,
      };

  Map<String, dynamic> mentorshipPairItem(MentorshipPair pair) => {
        'id': pair.id,
        'mentorName': pair.mentorName,
        'mentorAlumniId': pair.mentorAlumniId,
        'menteeName': pair.menteeName,
        'menteeBatch': pair.menteeBatch,
        'focusArea': pair.focusArea,
        'status': AlumniEnumCodec.mentorshipStatusToApi(pair.status),
        'sessionsCompleted': pair.sessionsCompleted,
      };

  Map<String, dynamic> dashboardEnvelope(AlumniDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'recentGraduates': [
        for (final record in data.recentGraduates) recordItem(record),
      ],
      'upcomingEvents': [
        for (final event in data.upcomingEvents) eventItem(event),
      ],
      'donationSummary': {
        'totalReceived': data.donationSummary.totalReceived,
        'pledgedAmount': data.donationSummary.pledgedAmount,
        'pendingAmount': data.donationSummary.pendingAmount,
        'financeLedgerRoute': data.donationSummary.financeLedgerRoute,
      },
      'engagement': {
        'activeAlumni': data.engagement.activeAlumni,
        'eventAttendanceRate': data.engagement.eventAttendanceRate,
        'mentorshipPairs': data.engagement.mentorshipPairs,
        'campaignParticipation': data.engagement.campaignParticipation,
      },
    });
  }

  Map<String, dynamic> alumniDetailEnvelope(AlumniDetail detail) {
    return envelope({
      'alumni': recordItem(detail.alumni),
      'employmentHistory': [
        for (final item in detail.employmentHistory)
          {
            'organization': item.organization,
            'role': item.role,
            'period': item.period,
          },
      ],
      'donationHistory': [
        for (final item in detail.donationHistory)
          {
            'id': item.id,
            'date': item.date,
            'amount': item.amount,
            'campaign': item.campaign,
            'status': AlumniEnumCodec.donationStatusToApi(item.status),
            'financeReceiptId': item.financeReceiptId,
          },
      ],
      'mentorshipRole': detail.mentorshipRole,
      'eventsAttended': detail.eventsAttended,
    });
  }

  Map<String, dynamic> reportsEnvelope(AlumniReportsData data) {
    return envelope({
      'catalog': [
        for (final item in data.catalog)
          {
            'id': item.id,
            'title': item.title,
            'description': item.description,
            'lastGenerated': item.lastGenerated,
          },
      ],
      'donationTrend': [
        for (final point in data.donationTrend) trendPoint(point),
      ],
      'engagementByBatch': [
        for (final segment in data.engagementByBatch) this.segment(segment),
      ],
      'eventAttendanceTrend': [
        for (final point in data.eventAttendanceTrend) trendPoint(point),
      ],
    });
  }

  Map<String, dynamic> settingsEnvelope(AlumniSettingsData data) {
    return envelope({
      'mobileCompanionEnabled': data.mobileCompanionEnabled,
      'sections': [
        for (final section in data.sections)
          {
            'id': section.id,
            'title': section.title,
            'items': [
              for (final item in section.items)
                {
                  'id': item.id,
                  'label': item.label,
                  'value': item.value,
                  'description': item.description,
                  'editable': item.editable,
                },
            ],
          },
      ],
    });
  }
}
