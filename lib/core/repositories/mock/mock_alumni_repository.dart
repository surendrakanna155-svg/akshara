import 'package:flutter/material.dart';

import '../../../features/alumni/alumni_models.dart';
import '../../../features/alumni/alumni_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/alumni_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';
import 'mock_alumni_write_store.dart';

class MockAlumniRepository implements AlumniRepository {
  static const _upcomingEvents = [
    AlumniEvent(
      id: 'evt_1',
      title: 'Annual Alumni Reunion 2026',
      date: '15 Aug 2026',
      venue: 'Akshara Main Campus',
      registrations: 156,
      capacity: 200,
      status: AlumniEventStatus.upcoming,
      organizer: 'Alumni Association',
    ),
    AlumniEvent(
      id: 'evt_2',
      title: 'Career Fair — Tech & Finance',
      date: '22 Jun 2026',
      venue: 'Auditorium Block A',
      registrations: 89,
      capacity: 120,
      status: AlumniEventStatus.upcoming,
      organizer: 'Career Services',
    ),
  ];

  static const _alumniRegistry = [
    AlumniRecord(
      id: 'ALM-001',
      name: 'Arjun Patel',
      batchYear: '2024',
      program: 'Class 12 — Science',
      currentRole: 'Software Engineer, Infosys',
      city: 'Hyderabad',
      email: 'arjun.patel@alumni.akshara.edu',
      phone: '+91 98765 10421',
      engagementStatus: AlumniEngagementStatus.active,
      sisStudentId: 'SIS-STU-10421',
      totalDonated: '₹25,000',
      lastEventAttended: 'Annual Reunion 2025',
    ),
    AlumniRecord(
      id: 'ALM-002',
      name: 'Priya Sharma',
      batchYear: '2023',
      program: 'Class 12 — Commerce',
      currentRole: 'CA, Deloitte',
      city: 'Bengaluru',
      email: 'priya.sharma@alumni.akshara.edu',
      phone: '+91 91234 10415',
      engagementStatus: AlumniEngagementStatus.active,
      sisStudentId: 'SIS-STU-10415',
      totalDonated: '₹50,000',
      lastEventAttended: 'Career Fair 2025',
    ),
    AlumniRecord(
      id: 'ALM-003',
      name: 'Rohan Mehta',
      batchYear: '2022',
      program: 'Class 12 — Science',
      currentRole: 'Medical Student, AIIMS',
      city: 'Delhi',
      email: 'rohan.mehta@alumni.akshara.edu',
      phone: '+91 99887 10418',
      engagementStatus: AlumniEngagementStatus.inactive,
      sisStudentId: 'SIS-STU-10418',
      totalDonated: '₹5,000',
      lastEventAttended: '—',
    ),
    AlumniRecord(
      id: 'ALM-004',
      name: 'Ananya Reddy',
      batchYear: '2025',
      program: 'Class 12 — Humanities',
      currentRole: 'Undergraduate, Ashoka University',
      city: 'Mumbai',
      email: 'ananya.reddy@alumni.akshara.edu',
      phone: '+91 94440 10422',
      engagementStatus: AlumniEngagementStatus.pending,
      sisStudentId: 'SIS-STU-10422',
      totalDonated: '—',
      lastEventAttended: 'Graduation Ceremony 2025',
    ),
    AlumniRecord(
      id: 'ALM-005',
      name: 'Kavya Iyer',
      batchYear: '2021',
      program: 'Class 12 — Science',
      currentRole: 'Product Manager, Google',
      city: 'San Francisco',
      email: 'kavya.iyer@alumni.akshara.edu',
      phone: '+1 415 555 0198',
      engagementStatus: AlumniEngagementStatus.active,
      sisStudentId: 'SIS-STU-10410',
      totalDonated: '₹1,20,000',
      lastEventAttended: 'Global Alumni Meet 2024',
    ),
  ];

  List<AlumniRecord> get _allAlumniRecords => [
        ...MockAlumniWriteStore.instance.graduates,
        ..._alumniRegistry,
      ];

  @override
  Future<AlumniDashboardData> getDashboard({required RepositoryQuery query}) async {
    return AlumniDashboardData(
      kpis: const [
        AlumniKpi(
          id: 'total_alumni',
          value: '1,248',
          label: 'Total Alumni',
          icon: Icons.school_outlined,
          accentName: 'primary',
        ),
        AlumniKpi(
          id: 'new_graduates',
          value: '86',
          label: 'New Graduates (YTD)',
          icon: Icons.celebration_outlined,
          accentName: 'success',
          detail: 'SIS graduates sync',
        ),
        AlumniKpi(
          id: 'donations_mtd',
          value: '₹4.2L',
          label: 'Donations (MTD)',
          icon: Icons.volunteer_activism_outlined,
          accentName: 'success',
          detail: 'Finance FN-05 placeholder',
        ),
        AlumniKpi(
          id: 'active_campaigns',
          value: '3',
          label: 'Active Campaigns',
          icon: Icons.campaign_outlined,
          accentName: 'primary',
        ),
        AlumniKpi(
          id: 'mentorship_pairs',
          value: '42',
          label: 'Mentorship Pairs',
          icon: Icons.handshake_outlined,
          accentName: 'neutral',
        ),
        AlumniKpi(
          id: 'event_rsvp',
          value: '156',
          label: 'Event RSVPs',
          icon: Icons.event_outlined,
          accentName: 'warning',
        ),
      ],
      recentGraduates: _allAlumniRecords.take(3).toList(),
      upcomingEvents: _upcomingEvents,
      donationSummary: const AlumniDonationSummary(
        totalReceived: '₹18.6L',
        pledgedAmount: '₹3.2L',
        pendingAmount: '₹1.1L',
        financeLedgerRoute: RouteNames.financeCollections,
      ),
      engagement: const AlumniEngagementMetrics(
        activeAlumni: 842,
        eventAttendanceRate: '68%',
        mentorshipPairs: 42,
        campaignParticipation: '24%',
      ),
      aiInsight:
          '12 SIS graduates from Class 12 (2025) pending alumni onboarding — link to SIS-02 registry. Annual Reunion has 78% RSVP rate; consider mentorship pairing for new graduates.',
    );
  }

  @override
  Future<PaginatedResult<AlumniRecord>> getAlumniRegistry({
    required RepositoryQuery query,
  }) async =>
      paginateList(_allAlumniRecords, query);

  @override
  Future<AlumniDetail?> getAlumniDetail({required RepositoryQuery query, required String alumniId}) async {
    final matches =
        _allAlumniRecords.where((a) => a.id == alumniId).toList(growable: false);
    if (matches.isEmpty) return null;
    final alumni = matches.first;

    return AlumniDetail(
      alumni: alumni,
      employmentHistory: switch (alumniId) {
        'ALM-001' => const [
            AlumniEmploymentHistory(
              organization: 'Infosys',
              role: 'Software Engineer',
              period: '2024 — Present',
            ),
            AlumniEmploymentHistory(
              organization: 'Akshara Internship',
              role: 'Tech Intern',
              period: '2023 — 2024',
            ),
          ],
        'ALM-002' => const [
            AlumniEmploymentHistory(
              organization: 'Deloitte',
              role: 'Chartered Accountant',
              period: '2023 — Present',
            ),
          ],
        _ => const [
            AlumniEmploymentHistory(
              organization: '—',
              role: 'Profile pending',
              period: '—',
            ),
          ],
      },
      donationHistory: switch (alumniId) {
        'ALM-001' => const [
            AlumniDonationHistoryItem(
              id: 'don_1',
              date: '15 Mar 2026',
              amount: '₹10,000',
              campaign: 'Library Fund 2026',
              status: AlumniDonationStatus.received,
              financeReceiptId: 'RCP-2026-8841',
            ),
            AlumniDonationHistoryItem(
              id: 'don_2',
              date: '10 Jan 2026',
              amount: '₹15,000',
              campaign: 'Scholarship Drive',
              status: AlumniDonationStatus.received,
              financeReceiptId: 'RCP-2026-7720',
            ),
          ],
        'ALM-005' => const [
            AlumniDonationHistoryItem(
              id: 'don_3',
              date: '1 Jun 2025',
              amount: '₹1,00,000',
              campaign: 'Infrastructure Upgrade',
              status: AlumniDonationStatus.received,
              financeReceiptId: 'RCP-2025-9901',
            ),
          ],
        _ => const [],
      },
      mentorshipRole: switch (alumniId) {
        'ALM-001' => 'Mentor — Career guidance (2 mentees)',
        'ALM-005' => 'Mentor — Product & tech (3 mentees)',
        _ => 'Not enrolled',
      },
      eventsAttended: switch (alumniId) {
        'ALM-001' => ['Annual Reunion 2025', 'Career Fair 2024'],
        'ALM-002' => ['Career Fair 2025', 'Annual Reunion 2024'],
        'ALM-005' => ['Global Alumni Meet 2024', 'Annual Reunion 2023'],
        _ => const [],
      },
    );
  }

  static const _seedEvents = [
    AlumniEvent(
      id: 'evt_1',
      title: 'Annual Alumni Reunion 2026',
      date: '15 Aug 2026',
      venue: 'Akshara Main Campus',
      registrations: 156,
      capacity: 200,
      status: AlumniEventStatus.upcoming,
      organizer: 'Alumni Association',
    ),
    AlumniEvent(
      id: 'evt_2',
      title: 'Career Fair — Tech & Finance',
      date: '22 Jun 2026',
      venue: 'Auditorium Block A',
      registrations: 89,
      capacity: 120,
      status: AlumniEventStatus.upcoming,
      organizer: 'Career Services',
    ),
    AlumniEvent(
      id: 'evt_3',
      title: 'Graduation Ceremony 2025',
      date: '28 Mar 2025',
      venue: 'Sports Complex',
      registrations: 320,
      capacity: 350,
      status: AlumniEventStatus.completed,
      organizer: 'Academic Office',
    ),
    AlumniEvent(
      id: 'evt_4',
      title: 'Mentorship Kickoff Workshop',
      date: '5 Jun 2026',
      venue: 'Conference Hall B',
      registrations: 42,
      capacity: 50,
      status: AlumniEventStatus.ongoing,
      organizer: 'Alumni Mentorship Program',
    ),
  ];

  List<AlumniEvent> get _allEvents => [
        ...MockAlumniWriteStore.instance.events,
        ..._seedEvents,
      ];

  @override
  Future<PaginatedResult<AlumniEvent>> getEvents({
    required RepositoryQuery query,
  }) async =>
      paginateList(_allEvents, query);

  @override
  Future<PaginatedResult<AlumniDonation>> getDonations({
    required RepositoryQuery query,
  }) async =>
      paginateList(const [
        AlumniDonation(
          id: 'don_1',
          alumniName: 'Arjun Patel',
          alumniId: 'ALM-001',
          amount: '₹10,000',
          date: '15 Mar 2026',
          campaign: 'Library Fund 2026',
          status: AlumniDonationStatus.received,
          financeReceiptId: 'RCP-2026-8841',
          paymentMode: 'UPI',
        ),
        AlumniDonation(
          id: 'don_2',
          alumniName: 'Priya Sharma',
          alumniId: 'ALM-002',
          amount: '₹25,000',
          date: '8 Mar 2026',
          campaign: 'Scholarship Drive',
          status: AlumniDonationStatus.received,
          financeReceiptId: 'RCP-2026-8835',
          paymentMode: 'Bank transfer',
        ),
        AlumniDonation(
          id: 'don_3',
          alumniName: 'Kavya Iyer',
          alumniId: 'ALM-005',
          amount: '₹50,000',
          date: '1 Jun 2026',
          campaign: 'Infrastructure Upgrade',
          status: AlumniDonationStatus.pledged,
          financeReceiptId: '—',
          paymentMode: 'Wire transfer',
        ),
        AlumniDonation(
          id: 'don_4',
          alumniName: 'Rohan Mehta',
          alumniId: 'ALM-003',
          amount: '₹5,000',
          date: '20 May 2026',
          campaign: 'Library Fund 2026',
          status: AlumniDonationStatus.pending,
          financeReceiptId: '—',
          paymentMode: 'Cheque',
        ),
      ], query);

  static const _seedCampaigns = [
    AlumniCampaign(
      id: 'camp_1',
      name: 'Library Fund 2026',
      goalAmount: '₹10L',
      raisedAmount: '₹6.2L',
      donorCount: 48,
      deadline: '31 Dec 2026',
      status: AlumniCampaignStatus.active,
      financeAccountCode: 'FN-ALM-LIB-2026',
    ),
    AlumniCampaign(
      id: 'camp_2',
      name: 'Scholarship Drive',
      goalAmount: '₹25L',
      raisedAmount: '₹12.4L',
      donorCount: 62,
      deadline: '30 Sep 2026',
      status: AlumniCampaignStatus.active,
      financeAccountCode: 'FN-ALM-SCH-2026',
    ),
    AlumniCampaign(
      id: 'camp_3',
      name: 'Sports Complex Renovation',
      goalAmount: '₹50L',
      raisedAmount: '₹8.0L',
      donorCount: 22,
      deadline: '31 Mar 2027',
      status: AlumniCampaignStatus.active,
      financeAccountCode: 'FN-ALM-SPT-2027',
    ),
    AlumniCampaign(
      id: 'camp_4',
      name: 'Class of 2020 Memorial Fund',
      goalAmount: '₹5L',
      raisedAmount: '₹5L',
      donorCount: 35,
      deadline: '31 Dec 2025',
      status: AlumniCampaignStatus.completed,
      financeAccountCode: 'FN-ALM-MEM-2025',
    ),
  ];

  List<AlumniCampaign> get _allCampaigns => [
        ...MockAlumniWriteStore.instance.campaigns,
        ..._seedCampaigns,
      ];

  @override
  Future<PaginatedResult<AlumniCampaign>> getCampaigns({
    required RepositoryQuery query,
  }) async =>
      paginateList(_allCampaigns, query);

  @override
  Future<PaginatedResult<MentorshipPair>> getMentorshipPairs({
    required RepositoryQuery query,
  }) async =>
      paginateList(const [
        MentorshipPair(
          id: 'mnt_1',
          mentorName: 'Arjun Patel',
          mentorAlumniId: 'ALM-001',
          menteeName: 'Vikram Singh',
          menteeBatch: 'Class 11 (2026)',
          focusArea: 'Software engineering careers',
          status: MentorshipStatus.active,
          sessionsCompleted: 4,
        ),
        MentorshipPair(
          id: 'mnt_2',
          mentorName: 'Kavya Iyer',
          mentorAlumniId: 'ALM-005',
          menteeName: 'Sneha Nair',
          menteeBatch: 'Class 12 (2025)',
          focusArea: 'Product management & startups',
          status: MentorshipStatus.active,
          sessionsCompleted: 6,
        ),
        MentorshipPair(
          id: 'mnt_3',
          mentorName: 'Priya Sharma',
          mentorAlumniId: 'ALM-002',
          menteeName: 'Aditya Rao',
          menteeBatch: 'Class 11 (2026)',
          focusArea: 'Finance & CA pathway',
          status: MentorshipStatus.pending,
          sessionsCompleted: 0,
        ),
        MentorshipPair(
          id: 'mnt_4',
          mentorName: 'Arjun Patel',
          mentorAlumniId: 'ALM-001',
          menteeName: 'Meera Joshi',
          menteeBatch: 'Class 10 (2027)',
          focusArea: 'STEM Olympiad preparation',
          status: MentorshipStatus.completed,
          sessionsCompleted: 8,
        ),
      ], query);

  @override
  Future<AlumniReportsData> getReports({required RepositoryQuery query}) async {
    return const AlumniReportsData(
      catalog: [
        AlumniReportCatalogItem(
          id: 'rpt_registry',
          title: 'Alumni Registry Export',
          description: 'Full alumni directory with SIS graduate links',
          lastGenerated: '5 Jun 2026',
        ),
        AlumniReportCatalogItem(
          id: 'rpt_donations',
          title: 'Donation Ledger',
          description: 'Finance FN-05 donation posting summary',
          lastGenerated: '5 Jun 2026',
        ),
        AlumniReportCatalogItem(
          id: 'rpt_campaigns',
          title: 'Campaign Performance',
          description: 'Goal vs raised by campaign',
          lastGenerated: '4 Jun 2026',
        ),
        AlumniReportCatalogItem(
          id: 'rpt_events',
          title: 'Event Attendance',
          description: 'RSVP and attendance by event',
          lastGenerated: '3 Jun 2026',
        ),
        AlumniReportCatalogItem(
          id: 'rpt_mentorship',
          title: 'Mentorship Activity',
          description: 'Pairs, sessions, and completion rates',
          lastGenerated: '2 Jun 2026',
        ),
        AlumniReportCatalogItem(
          id: 'rpt_engagement',
          title: 'Engagement by Batch',
          description: 'Active vs inactive alumni by graduation year',
          lastGenerated: '1 Jun 2026',
        ),
      ],
      donationTrend: [
        AlumniTrendPoint(label: 'Jan', amountLakhs: 1.2, targetLakhs: 2.0),
        AlumniTrendPoint(label: 'Feb', amountLakhs: 1.8, targetLakhs: 2.0),
        AlumniTrendPoint(label: 'Mar', amountLakhs: 2.4, targetLakhs: 2.5),
        AlumniTrendPoint(label: 'Apr', amountLakhs: 2.1, targetLakhs: 2.5),
        AlumniTrendPoint(label: 'May', amountLakhs: 3.0, targetLakhs: 3.0),
        AlumniTrendPoint(label: 'Jun', amountLakhs: 4.2, targetLakhs: 4.0),
      ],
      engagementByBatch: [
        AlumniSegment(label: '2025', value: 86, percent: 28),
        AlumniSegment(label: '2024', value: 72, percent: 24),
        AlumniSegment(label: '2023', value: 58, percent: 19),
        AlumniSegment(label: '2022', value: 45, percent: 15),
        AlumniSegment(label: 'Earlier', value: 42, percent: 14),
      ],
      eventAttendanceTrend: [
        AlumniTrendPoint(label: 'Jan', amountLakhs: 45, targetLakhs: 60),
        AlumniTrendPoint(label: 'Feb', amountLakhs: 52, targetLakhs: 60),
        AlumniTrendPoint(label: 'Mar', amountLakhs: 68, targetLakhs: 70),
        AlumniTrendPoint(label: 'Apr', amountLakhs: 55, targetLakhs: 70),
        AlumniTrendPoint(label: 'May', amountLakhs: 72, targetLakhs: 80),
        AlumniTrendPoint(label: 'Jun', amountLakhs: 78, targetLakhs: 80),
      ],
    );
  }

  @override
  Future<AlumniSettingsData> getSettings({required RepositoryQuery query}) async {
    return const AlumniSettingsData(
      mobileCompanionEnabled: true,
      sections: [
        AlumniSettingsSection(
          id: 'sis',
          title: 'SIS graduates integration',
          items: [
            AlumniSettingItem(
              id: 'graduate_sync',
              label: 'Graduate auto-onboarding',
              value: 'Enabled — SIS status = Alumni',
              description:
                  'Class 12 graduates sync from SIS-02 registry on exit',
              editable: false,
            ),
            AlumniSettingItem(
              id: 'profile_link',
              label: 'SIS profile link',
              value: 'Bidirectional placeholder',
              description: 'Alumni profile references SIS-STU IDs',
              editable: false,
            ),
          ],
        ),
        AlumniSettingsSection(
          id: 'finance',
          title: 'Finance donations integration',
          items: [
            AlumniSettingItem(
              id: 'donation_posting',
              label: 'Donation ledger posting',
              value: 'Linked to FN-05 collections',
              description: 'AL-05 donations post to Finance receipt ledger',
              editable: false,
            ),
            AlumniSettingItem(
              id: 'campaign_accounts',
              label: 'Campaign GL accounts',
              value: 'FN-ALM-* account codes',
              description: 'AL-06 campaigns map to Finance fee structures',
              editable: false,
            ),
            AlumniSettingItem(
              id: 'tax_receipts',
              label: '80G tax receipts',
              value: 'Finance FN-08 placeholder',
              description: 'Donation receipts generated via Finance module',
              editable: false,
            ),
          ],
        ),
        AlumniSettingsSection(
          id: 'parent',
          title: 'Parent ecosystem placeholders',
          items: [
            AlumniSettingItem(
              id: 'parent_events',
              label: 'Parent event invites',
              value: 'Disabled (sandbox)',
              description: 'Future: alumni events visible in Parent App PA-08',
              editable: true,
            ),
            AlumniSettingItem(
              id: 'family_donations',
              label: 'Family donation links',
              value: 'Parent dashboard placeholder',
              description: 'Parents of current students can donate via PA fees',
              editable: false,
            ),
          ],
        ),
        AlumniSettingsSection(
          id: 'mobile',
          title: 'AL-10 — Mobile Companion',
          items: [
            AlumniSettingItem(
              id: 'companion_app',
              label: 'Alumni mobile app',
              value: 'Sandbox — v0.1 placeholder',
              description:
                  'Dedicated alumni companion: events, donations, mentorship chat',
              editable: false,
            ),
            AlumniSettingItem(
              id: 'push_notifications',
              label: 'Push notifications',
              value: 'Event RSVP + campaign updates',
              description: 'Firebase push placeholder for alumni mobile',
              editable: true,
            ),
            AlumniSettingItem(
              id: 'deep_links',
              label: 'Deep link routes',
              value: '/alumni/mobile (future)',
              description: 'Mobile companion deep links to web ERP campaigns',
              editable: false,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<AlumniRecord> addAlumni({
    required RepositoryQuery query,
    required AddAlumniRequest request,
  }) async {
    return MockAlumniWriteStore.instance.addManualAlumni(request);
  }

  @override
  Future<AlumniEvent> createEvent({
    required RepositoryQuery query,
    required CreateAlumniEventRequest request,
  }) async {
    return MockAlumniWriteStore.instance.createEvent(request);
  }

  @override
  Future<AlumniCampaign> createCampaign({
    required RepositoryQuery query,
    required CreateAlumniCampaignRequest request,
  }) async {
    return MockAlumniWriteStore.instance.createCampaign(request);
  }
}
