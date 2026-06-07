import 'package:akshara_erp/features/alumni/alumni_models.dart';
import 'package:akshara_erp/features/alumni/alumni_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createProviderTestContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('Alumni providers', () {
    test('alumniDashboardProvider returns dashboard data', () async {      await container.read(alumniDashboardFutureProvider.future);

      final data = container.read(alumniDashboardProvider);

      expect(data, isNotNull);
      expect(data!.kpis, hasLength(6));
      expect(data.recentGraduates, isNotEmpty);
    });

    test('alumniDashboardProvider returns null when loading', () async {
      container = createProviderTestContainer(
        overrides: [
          alumniDashboardLoadingProvider.overrideWith((ref) => true),
        ],
      );

      expect(container.read(alumniDashboardProvider), isNull);
    });

    test('alumniRegistryProvider returns alumni records', () async {      await container.read(alumniRegistryFutureProvider.future);

      final alumni = container.read(alumniRegistryProvider);

      expect(alumni, isNotNull);
      expect(alumni!, hasLength(5));
    });

    test('alumniFilteredRegistryProvider filters active alumni', () async {
      container = createProviderTestContainer(
        overrides: [
          alumniRegistryFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(alumniFilteredRegistryProvider);
      expect(
        filtered.every((a) => a.engagementStatus == AlumniEngagementStatus.active),
        isTrue,
      );
    });

    test('alumniDetailProvider returns profile for known alumni', () async {      await container.read(alumniDetailFutureProvider('ALM-001').future);

      final detail = container.read(alumniDetailProvider('ALM-001'));

      expect(detail, isNotNull);
      expect(detail!.alumni.name, 'Arjun Patel');
      expect(detail.alumni.sisStudentId, startsWith('SIS-STU-'));
    });

    test('alumniEventsProvider returns events', () async {      await container.read(alumniEventsFutureProvider.future);

      final events = container.read(alumniEventsProvider);

      expect(events, isNotNull);
      expect(events!, hasLength(4));
    });

    test('alumniDonationsProvider returns donations', () async {      await container.read(alumniDonationsFutureProvider.future);

      final donations = container.read(alumniDonationsProvider);

      expect(donations, isNotNull);
      expect(donations!, hasLength(4));
      expect(donations.first.financeReceiptId, isNotEmpty);
    });

    test('alumniCampaignsProvider returns campaigns', () async {      await container.read(alumniCampaignsFutureProvider.future);

      final campaigns = container.read(alumniCampaignsProvider);

      expect(campaigns, isNotNull);
      expect(campaigns!, hasLength(4));
    });

    test('alumniMentorshipProvider returns mentorship pairs', () async {      await container.read(alumniMentorshipFutureProvider.future);

      final pairs = container.read(alumniMentorshipProvider);

      expect(pairs, isNotNull);
      expect(pairs!, hasLength(4));
    });

    test('alumniFilteredMentorshipProvider filters active pairs', () async {
      container = createProviderTestContainer(
        overrides: [
          alumniMentorshipFilterProvider.overrideWith((ref) => 1),
        ],
      );

      final filtered = container.read(alumniFilteredMentorshipProvider);
      expect(
        filtered.every((p) => p.status == MentorshipStatus.active),
        isTrue,
      );
    });

    test('alumniReportsProvider returns reports data', () async {      await container.read(alumniReportsFutureProvider.future);

      final data = container.read(alumniReportsProvider);

      expect(data, isNotNull);
      expect(data!.catalog, hasLength(6));
    });

    test('alumniSettingsProvider returns settings sections', () async {      await container.read(alumniSettingsFutureProvider.future);

      final data = container.read(alumniSettingsProvider);

      expect(data, isNotNull);
      expect(data!.sections.length, greaterThan(3));
      expect(data.mobileCompanionEnabled, isTrue);
    });
  });
}
