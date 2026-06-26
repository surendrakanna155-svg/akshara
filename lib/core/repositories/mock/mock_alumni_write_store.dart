import '../../../features/alumni/alumni_models.dart';
import '../../../features/alumni/alumni_requests.dart';
import '../../../features/sis/sis_models.dart';

/// Mutable alumni graduates produced when SIS marks a student as alumni.
final class MockAlumniWriteStore {
  MockAlumniWriteStore._();

  static final MockAlumniWriteStore instance = MockAlumniWriteStore._();

  final List<AlumniRecord> graduates = [];
  final List<AlumniEvent> events = [];
  final List<AlumniCampaign> campaigns = [];
  final List<MentorshipPair> mentorshipPairs = [];
  final List<AlumniDonation> donations = [];
  int _sequence = 100;
  int _eventSequence = 100;
  int _campaignSequence = 100;
  int _mentorshipSequence = 100;
  int _donationSequence = 100;

  void reset() {
    graduates.clear();
    events.clear();
    campaigns.clear();
    mentorshipPairs.clear();
    donations.clear();
    _sequence = 100;
    _eventSequence = 100;
    _campaignSequence = 100;
    _mentorshipSequence = 100;
    _donationSequence = 100;
  }

  bool hasGraduateForSisStudent(String sisStudentId) {
    return graduates.any((record) => record.sisStudentId == sisStudentId);
  }

  AlumniRecord onboardFromSisStudent(SisStudent student) {
    final existing = graduates
        .where((record) => record.sisStudentId == student.id)
        .toList(growable: false);
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final email = student.email.trim().isEmpty
        ? '${student.studentName.toLowerCase().replaceAll(' ', '.')}@alumni.akshara.edu'
        : student.email;

    final record = AlumniRecord(
      id: 'ALM-${++_sequence}',
      name: student.studentName,
      batchYear: DateTime.now().year.toString(),
      program: 'Class ${student.classLabel} — ${student.section}',
      currentRole: 'Graduate — profile pending',
      city: '—',
      email: email,
      phone: student.phone.trim().isEmpty ? '—' : student.phone,
      engagementStatus: AlumniEngagementStatus.pending,
      sisStudentId: student.id,
      totalDonated: '—',
      lastEventAttended: '—',
    );
    graduates.insert(0, record);
    return record;
  }

  /// Adds a manually-entered alumnus (e.g. legacy/pre-system graduates that
  /// were never in SIS). Not linked to a SIS student.
  AlumniRecord addManualAlumni(AddAlumniRequest request) {
    final name = request.name.trim();
    if (name.isEmpty) {
      throw StateError('Alumni name is required');
    }

    final record = AlumniRecord(
      id: 'ALM-${++_sequence}',
      name: name,
      batchYear: request.batchYear.trim().isEmpty
          ? DateTime.now().year.toString()
          : request.batchYear.trim(),
      program: request.program.trim().isEmpty ? '—' : request.program.trim(),
      currentRole:
          request.currentRole.trim().isEmpty ? '—' : request.currentRole.trim(),
      city: request.city.trim().isEmpty ? '—' : request.city.trim(),
      email: request.email.trim(),
      phone: request.phone.trim().isEmpty ? '—' : request.phone.trim(),
      engagementStatus: AlumniEngagementStatus.active,
      sisStudentId: '',
      totalDonated: '—',
      lastEventAttended: '—',
    );
    graduates.insert(0, record);
    return record;
  }

  /// Schedules a new alumni event. New events start with no registrations and
  /// an upcoming status.
  AlumniEvent createEvent(CreateAlumniEventRequest request) {
    final title = request.title.trim();
    if (title.isEmpty) {
      throw StateError('Event title is required');
    }

    final event = AlumniEvent(
      id: 'evt_new_${++_eventSequence}',
      title: title,
      date: request.date.trim().isEmpty ? '—' : request.date.trim(),
      venue: request.venue.trim().isEmpty ? '—' : request.venue.trim(),
      registrations: 0,
      capacity: int.tryParse(request.capacity.trim()) ?? 0,
      status: AlumniEventStatus.upcoming,
      organizer: request.organizer.trim().isEmpty
          ? 'Alumni Association'
          : request.organizer.trim(),
    );
    events.insert(0, event);
    return event;
  }

  /// Sets up a new fundraising campaign. New campaigns start in draft with no
  /// funds raised and no donors.
  AlumniCampaign createCampaign(CreateAlumniCampaignRequest request) {
    final name = request.name.trim();
    if (name.isEmpty) {
      throw StateError('Campaign name is required');
    }

    final campaign = AlumniCampaign(
      id: 'camp_new_${++_campaignSequence}',
      name: name,
      goalAmount: request.goalAmount.trim().isEmpty
          ? '—'
          : request.goalAmount.trim(),
      raisedAmount: '₹0',
      donorCount: 0,
      deadline: request.deadline.trim().isEmpty ? '—' : request.deadline.trim(),
      status: AlumniCampaignStatus.draft,
      financeAccountCode: request.financeAccountCode.trim().isEmpty
          ? 'FN-ALM-PENDING'
          : request.financeAccountCode.trim(),
    );
    campaigns.insert(0, campaign);
    return campaign;
  }

  /// Matches a mentor with a mentee. New pairs start pending with no sessions
  /// completed.
  MentorshipPair addMentorshipPair(AddMentorshipPairRequest request) {
    final mentorName = request.mentorName.trim();
    final menteeName = request.menteeName.trim();
    if (mentorName.isEmpty || menteeName.isEmpty) {
      throw StateError('Mentor and mentee names are required');
    }

    final pair = MentorshipPair(
      id: 'mnt_new_${++_mentorshipSequence}',
      mentorName: mentorName,
      mentorAlumniId: request.mentorAlumniId.trim().isEmpty
          ? '—'
          : request.mentorAlumniId.trim(),
      menteeName: menteeName,
      menteeBatch:
          request.menteeBatch.trim().isEmpty ? '—' : request.menteeBatch.trim(),
      focusArea:
          request.focusArea.trim().isEmpty ? '—' : request.focusArea.trim(),
      status: MentorshipStatus.pending,
      sessionsCompleted: 0,
    );
    mentorshipPairs.insert(0, pair);
    return pair;
  }

  /// Records a donation against the alumni ledger. When the donation references
  /// a [campaign] held in this write store, that campaign's donor count is
  /// incremented (mirrors the live campaign raisedAmount/donorCount increment).
  AlumniDonation recordDonation(
    RecordDonationRequest request, {
    String? campaignName,
  }) {
    final donor = request.alumniName.trim();
    if (donor.isEmpty) {
      throw StateError('Donor name is required');
    }
    final amount = request.amount.trim();
    if (amount.isEmpty) {
      throw StateError('Donation amount is required');
    }

    final campaignId = request.campaignId.trim();
    var resolvedCampaign = campaignName?.trim() ?? '';
    if (campaignId.isNotEmpty) {
      final index = campaigns.indexWhere((c) => c.id == campaignId);
      if (index != -1) {
        final existing = campaigns[index];
        if (resolvedCampaign.isEmpty) resolvedCampaign = existing.name;
        campaigns[index] = AlumniCampaign(
          id: existing.id,
          name: existing.name,
          goalAmount: existing.goalAmount,
          raisedAmount: existing.raisedAmount,
          donorCount: existing.donorCount + 1,
          deadline: existing.deadline,
          status: existing.status,
          financeAccountCode: existing.financeAccountCode,
        );
      }
    }

    final donation = AlumniDonation(
      id: 'don_new_${++_donationSequence}',
      alumniName: donor,
      alumniId: request.alumniId.trim(),
      amount: amount,
      date: request.date.trim().isEmpty ? '—' : request.date.trim(),
      campaign: resolvedCampaign.isEmpty ? '—' : resolvedCampaign,
      status: _parseDonationStatus(request.status),
      financeReceiptId: '—',
      paymentMode: request.paymentMode.trim(),
    );
    donations.insert(0, donation);
    return donation;
  }

  static AlumniDonationStatus _parseDonationStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pledged':
        return AlumniDonationStatus.pledged;
      case 'pending':
        return AlumniDonationStatus.pending;
      case 'refunded':
        return AlumniDonationStatus.refunded;
      default:
        return AlumniDonationStatus.received;
    }
  }
}
