import 'package:akshara_erp/core/repositories/mock/mock_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_alumni_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/alumni/alumni_models.dart';
import 'package:akshara_erp/features/alumni/alumni_mutations_provider.dart';
import 'package:akshara_erp/features/alumni/alumni_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockAlumniWriteStore.instance.reset();
  });

  group('Alumni mock writes', () {
    const query = RepositoryQuery.demo;

    test('addAlumni inserts an active, SIS-unlinked record', () async {
      final repo = MockAlumniRepository();
      final before = await repo.getAlumniRegistry(query: query);

      final alumni = await repo.addAlumni(
        query: query,
        request: const AddAlumniRequest(
          name: 'Meera Iyer',
          batchYear: '2011',
          program: 'Class 12 — Commerce',
          currentRole: 'Chartered Accountant',
          city: 'Chennai',
          email: 'meera.iyer@example.com',
          phone: '+91 90000 00000',
        ),
      );

      final after = await repo.getAlumniRegistry(query: query);
      expect(after.total, before.total + 1);
      expect(alumni.engagementStatus, AlumniEngagementStatus.active);
      expect(alumni.sisStudentId, '');
      expect(after.items.any((a) => a.id == alumni.id), isTrue);
    });

    test('addAlumni rejects an empty name', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.addAlumni(
          query: query,
          request: const AddAlumniRequest(
            name: '  ',
            batchYear: '2011',
            program: '',
            currentRole: '',
            city: '',
            email: '',
            phone: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('createEvent inserts an upcoming, zero-RSVP event', () async {
      final repo = MockAlumniRepository();
      final before = await repo.getEvents(query: query);

      final event = await repo.createEvent(
        query: query,
        request: const CreateAlumniEventRequest(
          title: 'Founders Day Meet 2026',
          date: '12 Sep 2026',
          venue: 'Innovation Hall',
          capacity: '150',
          organizer: 'Alumni Association',
        ),
      );

      final after = await repo.getEvents(query: query);
      expect(after.total, before.total + 1);
      expect(event.status, AlumniEventStatus.upcoming);
      expect(event.registrations, 0);
      expect(event.capacity, 150);
      expect(after.items.any((e) => e.id == event.id), isTrue);
    });

    test('createEvent rejects an empty title', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.createEvent(
          query: query,
          request: const CreateAlumniEventRequest(
            title: '  ',
            date: '',
            venue: '',
            capacity: '',
            organizer: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('createCampaign inserts a draft, zero-raised campaign', () async {
      final repo = MockAlumniRepository();
      final before = await repo.getCampaigns(query: query);

      final campaign = await repo.createCampaign(
        query: query,
        request: const CreateAlumniCampaignRequest(
          name: 'Robotics Lab Fund 2026',
          goalAmount: '₹15L',
          deadline: '31 Dec 2026',
          financeAccountCode: 'FN-ALM-ROB-2026',
        ),
      );

      final after = await repo.getCampaigns(query: query);
      expect(after.total, before.total + 1);
      expect(campaign.status, AlumniCampaignStatus.draft);
      expect(campaign.raisedAmount, '₹0');
      expect(campaign.donorCount, 0);
      expect(after.items.any((c) => c.id == campaign.id), isTrue);
    });

    test('createCampaign rejects an empty name', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.createCampaign(
          query: query,
          request: const CreateAlumniCampaignRequest(
            name: '  ',
            goalAmount: '',
            deadline: '',
            financeAccountCode: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('addMentorshipPair inserts a pending, zero-session pair', () async {
      final repo = MockAlumniRepository();
      final before = await repo.getMentorshipPairs(query: query);

      final pair = await repo.addMentorshipPair(
        query: query,
        request: const AddMentorshipPairRequest(
          mentorName: 'Kavya Iyer',
          mentorAlumniId: 'ALM-005',
          menteeName: 'Rahul Verma',
          menteeBatch: 'Class 12 (2026)',
          focusArea: 'Product management',
        ),
      );

      final after = await repo.getMentorshipPairs(query: query);
      expect(after.total, before.total + 1);
      expect(pair.status, MentorshipStatus.pending);
      expect(pair.sessionsCompleted, 0);
      expect(after.items.any((p) => p.id == pair.id), isTrue);
    });

    test('addMentorshipPair rejects an empty mentee name', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.addMentorshipPair(
          query: query,
          request: const AddMentorshipPairRequest(
            mentorName: 'Kavya Iyer',
            mentorAlumniId: 'ALM-005',
            menteeName: '  ',
            menteeBatch: '',
            focusArea: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('recordDonation surfaces in the donation ledger', () async {
      final repo = MockAlumniRepository();
      final before = await repo.getDonations(query: query);

      final donation = await repo.recordDonation(
        query: query,
        request: const RecordDonationRequest(
          alumniName: 'Arjun Patel',
          alumniId: 'ALM-001',
          amount: '₹12,000',
          date: '20 Jun 2026',
          campaignId: '',
          status: 'received',
          paymentMode: 'UPI',
        ),
      );

      final after = await repo.getDonations(query: query);
      expect(after.total, before.total + 1);
      expect(donation.status, AlumniDonationStatus.received);
      expect(donation.amount, '₹12,000');
      expect(after.items.any((d) => d.id == donation.id), isTrue);
    });

    test('recordDonation increments a referenced campaign donor count',
        () async {
      final repo = MockAlumniRepository();
      final campaign = await repo.createCampaign(
        query: query,
        request: const CreateAlumniCampaignRequest(
          name: 'Science Lab Fund',
          goalAmount: '₹8L',
          deadline: '31 Dec 2026',
          financeAccountCode: 'FN-ALM-SCI-2026',
        ),
      );
      expect(campaign.donorCount, 0);

      final donation = await repo.recordDonation(
        query: query,
        request: RecordDonationRequest(
          alumniName: 'Priya Sharma',
          alumniId: 'ALM-002',
          amount: '₹30,000',
          date: '21 Jun 2026',
          campaignId: campaign.id,
          status: 'received',
          paymentMode: 'Bank transfer',
        ),
      );

      // Donation is attributed to the campaign by name.
      expect(donation.campaign, 'Science Lab Fund');

      final campaigns = await repo.getCampaigns(query: query);
      final updated =
          campaigns.items.firstWhere((c) => c.id == campaign.id);
      expect(updated.donorCount, 1);
    });

    test('recordDonation rejects an empty donor', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.recordDonation(
          query: query,
          request: const RecordDonationRequest(
            alumniName: '  ',
            alumniId: '',
            amount: '₹1,000',
            date: '',
            campaignId: '',
            status: 'received',
            paymentMode: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('recordDonation rejects an empty amount', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.recordDonation(
          query: query,
          request: const RecordDonationRequest(
            alumniName: 'Arjun Patel',
            alumniId: 'ALM-001',
            amount: '  ',
            date: '',
            campaignId: '',
            status: 'received',
            paymentMode: '',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('Alumni RBAC mutations', () {
    test('addAlumni fails without manageAlumni', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addAlumniProvider.notifier).execute(
            const AddAlumniRequest(
              name: 'Blocked Alumnus',
              batchYear: '2011',
              program: '',
              currentRole: '',
              city: '',
              email: '',
              phone: '',
            ),
          );

      expect(container.read(addAlumniProvider).hasError, isTrue);
    });

    test('addAlumni succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addAlumniProvider.notifier).execute(
            const AddAlumniRequest(
              name: 'Allowed Alumnus',
              batchYear: '2012',
              program: '',
              currentRole: '',
              city: '',
              email: '',
              phone: '',
            ),
          );

      expect(container.read(addAlumniProvider).hasValue, isTrue);
      expect(
        container.read(addAlumniProvider).value?.engagementStatus,
        AlumniEngagementStatus.active,
      );
    });

    test('createEvent fails without manageAlumni', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createAlumniEventProvider.notifier).execute(
            const CreateAlumniEventRequest(
              title: 'Blocked Event',
              date: '',
              venue: '',
              capacity: '',
              organizer: '',
            ),
          );

      expect(container.read(createAlumniEventProvider).hasError, isTrue);
    });

    test('createEvent succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createAlumniEventProvider.notifier).execute(
            const CreateAlumniEventRequest(
              title: 'Allowed Event',
              date: '1 Oct 2026',
              venue: 'Hall A',
              capacity: '80',
              organizer: 'Alumni Association',
            ),
          );

      expect(container.read(createAlumniEventProvider).hasValue, isTrue);
      expect(
        container.read(createAlumniEventProvider).value?.status,
        AlumniEventStatus.upcoming,
      );
    });

    test('createCampaign fails without manageAlumni', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createAlumniCampaignProvider.notifier).execute(
            const CreateAlumniCampaignRequest(
              name: 'Blocked Campaign',
              goalAmount: '',
              deadline: '',
              financeAccountCode: '',
            ),
          );

      expect(container.read(createAlumniCampaignProvider).hasError, isTrue);
    });

    test('createCampaign succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createAlumniCampaignProvider.notifier).execute(
            const CreateAlumniCampaignRequest(
              name: 'Allowed Campaign',
              goalAmount: '₹5L',
              deadline: '30 Nov 2026',
              financeAccountCode: 'FN-ALM-NEW-2026',
            ),
          );

      expect(container.read(createAlumniCampaignProvider).hasValue, isTrue);
      expect(
        container.read(createAlumniCampaignProvider).value?.status,
        AlumniCampaignStatus.draft,
      );
    });

    test('addMentorshipPair fails without manageAlumni', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addMentorshipPairProvider.notifier).execute(
            const AddMentorshipPairRequest(
              mentorName: 'Blocked Mentor',
              mentorAlumniId: '',
              menteeName: 'Blocked Mentee',
              menteeBatch: '',
              focusArea: '',
            ),
          );

      expect(container.read(addMentorshipPairProvider).hasError, isTrue);
    });

    test('addMentorshipPair succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addMentorshipPairProvider.notifier).execute(
            const AddMentorshipPairRequest(
              mentorName: 'Allowed Mentor',
              mentorAlumniId: 'ALM-001',
              menteeName: 'Allowed Mentee',
              menteeBatch: 'Class 11 (2026)',
              focusArea: 'Careers',
            ),
          );

      expect(container.read(addMentorshipPairProvider).hasValue, isTrue);
      expect(
        container.read(addMentorshipPairProvider).value?.status,
        MentorshipStatus.pending,
      );
    });

    test('recordDonation fails without manageAlumni', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordDonationProvider.notifier).execute(
            const RecordDonationRequest(
              alumniName: 'Blocked Donor',
              alumniId: '',
              amount: '₹1,000',
              date: '',
              campaignId: '',
              status: 'received',
              paymentMode: '',
            ),
          );

      expect(container.read(recordDonationProvider).hasError, isTrue);
    });

    test('recordDonation succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordDonationProvider.notifier).execute(
            const RecordDonationRequest(
              alumniName: 'Allowed Donor',
              alumniId: 'ALM-001',
              amount: '₹5,000',
              date: '22 Jun 2026',
              campaignId: '',
              status: 'received',
              paymentMode: 'UPI',
            ),
          );

      expect(container.read(recordDonationProvider).hasValue, isTrue);
      expect(
        container.read(recordDonationProvider).value?.status,
        AlumniDonationStatus.received,
      );
    });
  });
}
