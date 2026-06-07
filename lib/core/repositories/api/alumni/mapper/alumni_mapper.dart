import '../../../../../features/alumni/alumni_models.dart';
import '../dto/alumni_enum_codec.dart';
import '../dto/alumni_responses_dto.dart';

/// Maps Alumni API DTOs to domain models.
class AlumniMapper {
  const AlumniMapper();

  AlumniDashboardData toDashboard(AlumniDashboardDto dto) {
    final raw = dto.raw;
    return AlumniDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      recentGraduates: _mapRecords(
        raw['recentGraduates'] as List<dynamic>? ?? const [],
      ),
      upcomingEvents: _mapEvents(
        raw['upcomingEvents'] as List<dynamic>? ?? const [],
      ),
      donationSummary: _mapDonationSummary(
        raw['donationSummary'] as Map<String, dynamic>? ?? const {},
      ),
      engagement: _mapEngagement(
        raw['engagement'] as Map<String, dynamic>? ?? const {},
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<AlumniRecord> toRegistry(AlumniRegistryResponseDto dto) {
    return [for (final item in dto.items) toRecord(item)];
  }

  AlumniRecord toRecord(AlumniRecordDto dto) {
    final raw = dto.raw;
    return AlumniRecord(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      batchYear: raw['batchYear'] as String? ?? '',
      program: raw['program'] as String? ?? '',
      currentRole: raw['currentRole'] as String? ?? '',
      city: raw['city'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      engagementStatus: AlumniEnumCodec.parseEngagementStatus(
        raw['engagementStatus'] as String?,
      ),
      sisStudentId: raw['sisStudentId'] as String? ?? '',
      totalDonated: raw['totalDonated'] as String? ?? '',
      lastEventAttended: raw['lastEventAttended'] as String? ?? '',
    );
  }

  AlumniDetail? toAlumniDetail(AlumniDetailDto dto) {
    final raw = dto.raw;
    if (raw.isEmpty) return null;

    final alumniRaw = raw['alumni'] as Map<String, dynamic>?;
    if (alumniRaw == null || (alumniRaw['id'] as String?)?.isEmpty == true) {
      return null;
    }

    return AlumniDetail(
      alumni: toRecord(AlumniRecordDto.fromJson(alumniRaw)),
      employmentHistory: _mapEmploymentHistory(
        raw['employmentHistory'] as List<dynamic>? ?? const [],
      ),
      donationHistory: _mapDonationHistory(
        raw['donationHistory'] as List<dynamic>? ?? const [],
      ),
      mentorshipRole: raw['mentorshipRole'] as String? ?? '',
      eventsAttended: _stringList(raw['eventsAttended']),
    );
  }

  List<AlumniEvent> toEvents(AlumniEventsResponseDto dto) {
    return [for (final item in dto.items) toEvent(item)];
  }

  AlumniEvent toEvent(AlumniEventDto dto) {
    final raw = dto.raw;
    return AlumniEvent(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      date: raw['date'] as String? ?? '',
      venue: raw['venue'] as String? ?? '',
      registrations: raw['registrations'] as int? ?? 0,
      capacity: raw['capacity'] as int? ?? 0,
      status: AlumniEnumCodec.parseEventStatus(raw['status'] as String?),
      organizer: raw['organizer'] as String? ?? '',
    );
  }

  List<AlumniDonation> toDonations(AlumniDonationsResponseDto dto) {
    return [for (final item in dto.items) toDonation(item)];
  }

  AlumniDonation toDonation(AlumniDonationDto dto) {
    final raw = dto.raw;
    return AlumniDonation(
      id: raw['id'] as String? ?? '',
      alumniName: raw['alumniName'] as String? ?? '',
      alumniId: raw['alumniId'] as String? ?? '',
      amount: raw['amount'] as String? ?? '',
      date: raw['date'] as String? ?? '',
      campaign: raw['campaign'] as String? ?? '',
      status: AlumniEnumCodec.parseDonationStatus(raw['status'] as String?),
      financeReceiptId: raw['financeReceiptId'] as String? ?? '',
      paymentMode: raw['paymentMode'] as String? ?? '',
    );
  }

  List<AlumniCampaign> toCampaigns(AlumniCampaignsResponseDto dto) {
    return [for (final item in dto.items) toCampaign(item)];
  }

  AlumniCampaign toCampaign(AlumniCampaignDto dto) {
    final raw = dto.raw;
    return AlumniCampaign(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      goalAmount: raw['goalAmount'] as String? ?? '',
      raisedAmount: raw['raisedAmount'] as String? ?? '',
      donorCount: raw['donorCount'] as int? ?? 0,
      deadline: raw['deadline'] as String? ?? '',
      status: AlumniEnumCodec.parseCampaignStatus(raw['status'] as String?),
      financeAccountCode: raw['financeAccountCode'] as String? ?? '',
    );
  }

  List<MentorshipPair> toMentorshipPairs(MentorshipPairsResponseDto dto) {
    return [for (final item in dto.items) toMentorshipPair(item)];
  }

  MentorshipPair toMentorshipPair(MentorshipPairDto dto) {
    final raw = dto.raw;
    return MentorshipPair(
      id: raw['id'] as String? ?? '',
      mentorName: raw['mentorName'] as String? ?? '',
      mentorAlumniId: raw['mentorAlumniId'] as String? ?? '',
      menteeName: raw['menteeName'] as String? ?? '',
      menteeBatch: raw['menteeBatch'] as String? ?? '',
      focusArea: raw['focusArea'] as String? ?? '',
      status: AlumniEnumCodec.parseMentorshipStatus(raw['status'] as String?),
      sessionsCompleted: raw['sessionsCompleted'] as int? ?? 0,
    );
  }

  AlumniReportsData toReports(AlumniReportsResponseDto dto) {
    final raw = dto.raw;
    return AlumniReportsData(
      catalog: _mapReportCatalog(
        raw['catalog'] as List<dynamic>? ?? const [],
      ),
      donationTrend: _mapTrendPoints(
        raw['donationTrend'] as List<dynamic>? ?? const [],
      ),
      engagementByBatch: _mapSegments(
        raw['engagementByBatch'] as List<dynamic>? ?? const [],
      ),
      eventAttendanceTrend: _mapTrendPoints(
        raw['eventAttendanceTrend'] as List<dynamic>? ?? const [],
      ),
    );
  }

  AlumniSettingsData toSettings(AlumniSettingsResponseDto dto) {
    final raw = dto.raw;
    return AlumniSettingsData(
      sections: _mapSettingsSections(
        raw['sections'] as List<dynamic>? ?? const [],
      ),
      mobileCompanionEnabled: raw['mobileCompanionEnabled'] as bool? ?? false,
    );
  }

  List<AlumniKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: AlumniEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<AlumniRecord> _mapRecords(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          toRecord(AlumniRecordDto.fromJson(item)),
    ];
  }

  List<AlumniEvent> _mapEvents(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          toEvent(AlumniEventDto.fromJson(item)),
    ];
  }

  AlumniDonationSummary _mapDonationSummary(Map<String, dynamic> raw) {
    return AlumniDonationSummary(
      totalReceived: raw['totalReceived'] as String? ?? '',
      pledgedAmount: raw['pledgedAmount'] as String? ?? '',
      pendingAmount: raw['pendingAmount'] as String? ?? '',
      financeLedgerRoute: raw['financeLedgerRoute'] as String? ?? '',
    );
  }

  AlumniEngagementMetrics _mapEngagement(Map<String, dynamic> raw) {
    return AlumniEngagementMetrics(
      activeAlumni: raw['activeAlumni'] as int? ?? 0,
      eventAttendanceRate: raw['eventAttendanceRate'] as String? ?? '',
      mentorshipPairs: raw['mentorshipPairs'] as int? ?? 0,
      campaignParticipation: raw['campaignParticipation'] as String? ?? '',
    );
  }

  List<AlumniEmploymentHistory> _mapEmploymentHistory(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniEmploymentHistory(
            organization: item['organization'] as String? ?? '',
            role: item['role'] as String? ?? '',
            period: item['period'] as String? ?? '',
          ),
    ];
  }

  List<AlumniDonationHistoryItem> _mapDonationHistory(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniDonationHistoryItem(
            id: item['id'] as String? ?? '',
            date: item['date'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            campaign: item['campaign'] as String? ?? '',
            status: AlumniEnumCodec.parseDonationStatus(
              item['status'] as String?,
            ),
            financeReceiptId: item['financeReceiptId'] as String? ?? '',
          ),
    ];
  }

  List<AlumniTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<AlumniSegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniSegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<AlumniReportCatalogItem> _mapReportCatalog(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniReportCatalogItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            lastGenerated: item['lastGenerated'] as String? ?? '',
          ),
    ];
  }

  List<AlumniSettingsSection> _mapSettingsSections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniSettingsSection(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            items: _mapSettingItems(item['items'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<AlumniSettingItem> _mapSettingItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AlumniSettingItem(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            description: item['description'] as String? ?? '',
            editable: item['editable'] as bool? ?? false,
          ),
    ];
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null) '$item',
    ];
  }
}
