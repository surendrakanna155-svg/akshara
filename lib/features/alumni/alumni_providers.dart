import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_provider.dart';
import '../../core/providers/repository_future.dart';

import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_providers.dart';
import 'alumni_models.dart';

// AL-01 Dashboard
final alumniDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final alumniDashboardErrorProvider = StateProvider<bool>((ref) => false);
final alumniDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final alumniDashboardFilterProvider = StateProvider<int>((ref) => 0);

final alumniDashboardFutureProvider = FutureProvider<AlumniDashboardData>((ref) async {
return await ref.read(alumniRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final alumniDashboardProvider = Provider<AlumniDashboardData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniDashboardFutureProvider),
    manualLoading: ref.watch(alumniDashboardLoadingProvider), manualError: ref.watch(alumniDashboardErrorProvider), manualEmpty: ref.watch(alumniDashboardEmptyProvider),
  );
});

// AL-02 Registry
final alumniRegistryLoadingProvider = StateProvider<bool>((ref) => false);
final alumniRegistryErrorProvider = StateProvider<bool>((ref) => false);
final alumniRegistryEmptyProvider = StateProvider<bool>((ref) => false);
final alumniRegistryFilterProvider = StateProvider<int>((ref) => 0);

final alumniRegistryFutureProvider = FutureProvider<PaginatedResult<AlumniRecord>>((ref) async {
return ref.read(alumniRepositoryProvider).getAlumniRegistry(query: ref.watch(repositoryQueryProvider));
});

final alumniRegistryProvider = Provider<List<AlumniRecord>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniRegistryFutureProvider),
    manualLoading: ref.watch(alumniRegistryLoadingProvider), manualError: ref.watch(alumniRegistryErrorProvider), manualEmpty: ref.watch(alumniRegistryEmptyProvider),
  )?.items ?? const [];
});

final alumniFilteredRegistryProvider = Provider<List<AlumniRecord>>((ref) {
  final alumni = ref.watch(alumniRegistryProvider);
  if (alumni == null) return const [];
  final filterIndex = ref.watch(alumniRegistryFilterProvider);
  return switch (filterIndex) {
    1 => alumni
        .where((a) => a.engagementStatus == AlumniEngagementStatus.active)
        .toList(),
    2 => alumni
        .where((a) => a.engagementStatus == AlumniEngagementStatus.inactive)
        .toList(),
    3 => alumni
        .where((a) => a.engagementStatus == AlumniEngagementStatus.pending)
        .toList(),
    _ => alumni,
  };
});

// AL-03 Profile (child route)
final alumniProfileLoadingProvider = StateProvider<bool>((ref) => false);
final alumniProfileErrorProvider = StateProvider<bool>((ref) => false);

final alumniDetailFutureProvider =
    FutureProvider.family<AlumniDetail?, String>((ref, alumniId) async {
  return ref.read(alumniRepositoryProvider).getAlumniDetail(
        query: ref.watch(repositoryQueryProvider),
        alumniId: alumniId,
      );
});

final alumniDetailProvider =
    Provider.family<AlumniDetail?, String>((ref, alumniId) {
  if (ref.watch(alumniProfileLoadingProvider)) return null;
  if (ref.watch(alumniProfileErrorProvider)) return null;
  return watchRepositoryFuture<AlumniDetail?>(
    ref,
    ref.watch(alumniDetailFutureProvider(alumniId)),
    manualLoading: false,
    manualError: false,
    manualEmpty: false,
  );
});

// AL-04 Events
final alumniEventsLoadingProvider = StateProvider<bool>((ref) => false);
final alumniEventsErrorProvider = StateProvider<bool>((ref) => false);
final alumniEventsEmptyProvider = StateProvider<bool>((ref) => false);
final alumniEventsFilterProvider = StateProvider<int>((ref) => 0);

final alumniEventsFutureProvider = FutureProvider<PaginatedResult<AlumniEvent>>((ref) async {
return ref.read(alumniRepositoryProvider).getEvents(query: ref.watch(repositoryQueryProvider));
});

final alumniEventsProvider = Provider<List<AlumniEvent>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniEventsFutureProvider),
    manualLoading: ref.watch(alumniEventsLoadingProvider), manualError: ref.watch(alumniEventsErrorProvider), manualEmpty: ref.watch(alumniEventsEmptyProvider),
  )?.items ?? const [];
});

final alumniFilteredEventsProvider = Provider<List<AlumniEvent>>((ref) {
  final events = ref.watch(alumniEventsProvider);
  if (events == null) return const [];
  final filterIndex = ref.watch(alumniEventsFilterProvider);
  return switch (filterIndex) {
    1 => events
        .where((e) => e.status == AlumniEventStatus.upcoming)
        .toList(),
    2 => events
        .where((e) => e.status == AlumniEventStatus.ongoing)
        .toList(),
    3 => events
        .where((e) => e.status == AlumniEventStatus.completed)
        .toList(),
    _ => events,
  };
});

// AL-05 Donations
final alumniDonationsLoadingProvider = StateProvider<bool>((ref) => false);
final alumniDonationsErrorProvider = StateProvider<bool>((ref) => false);
final alumniDonationsEmptyProvider = StateProvider<bool>((ref) => false);
final alumniDonationsFilterProvider = StateProvider<int>((ref) => 0);

final alumniDonationsFutureProvider = FutureProvider<PaginatedResult<AlumniDonation>>((ref) async {
return ref.read(alumniRepositoryProvider).getDonations(query: ref.watch(repositoryQueryProvider));
});

final alumniDonationsProvider = Provider<List<AlumniDonation>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniDonationsFutureProvider),
    manualLoading: ref.watch(alumniDonationsLoadingProvider), manualError: ref.watch(alumniDonationsErrorProvider), manualEmpty: ref.watch(alumniDonationsEmptyProvider),
  )?.items ?? const [];
});

final alumniFilteredDonationsProvider = Provider<List<AlumniDonation>>((ref) {
  final donations = ref.watch(alumniDonationsProvider);
  if (donations == null) return const [];
  final filterIndex = ref.watch(alumniDonationsFilterProvider);
  return switch (filterIndex) {
    1 => donations
        .where((d) => d.status == AlumniDonationStatus.received)
        .toList(),
    2 => donations
        .where((d) => d.status == AlumniDonationStatus.pledged)
        .toList(),
    3 => donations
        .where((d) => d.status == AlumniDonationStatus.pending)
        .toList(),
    _ => donations,
  };
});

// AL-06 Campaigns
final alumniCampaignsLoadingProvider = StateProvider<bool>((ref) => false);
final alumniCampaignsErrorProvider = StateProvider<bool>((ref) => false);
final alumniCampaignsEmptyProvider = StateProvider<bool>((ref) => false);
final alumniCampaignsFilterProvider = StateProvider<int>((ref) => 0);

final alumniCampaignsFutureProvider = FutureProvider<PaginatedResult<AlumniCampaign>>((ref) async {
return ref.read(alumniRepositoryProvider).getCampaigns(query: ref.watch(repositoryQueryProvider));
});

final alumniCampaignsProvider = Provider<List<AlumniCampaign>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniCampaignsFutureProvider),
    manualLoading: ref.watch(alumniCampaignsLoadingProvider), manualError: ref.watch(alumniCampaignsErrorProvider), manualEmpty: ref.watch(alumniCampaignsEmptyProvider),
  )?.items ?? const [];
});

final alumniFilteredCampaignsProvider = Provider<List<AlumniCampaign>>((ref) {
  final campaigns = ref.watch(alumniCampaignsProvider);
  if (campaigns == null) return const [];
  final filterIndex = ref.watch(alumniCampaignsFilterProvider);
  return switch (filterIndex) {
    1 => campaigns
        .where((c) => c.status == AlumniCampaignStatus.active)
        .toList(),
    2 => campaigns
        .where((c) => c.status == AlumniCampaignStatus.draft)
        .toList(),
    3 => campaigns
        .where((c) => c.status == AlumniCampaignStatus.completed)
        .toList(),
    _ => campaigns,
  };
});

// AL-07 Mentorship
final alumniMentorshipLoadingProvider = StateProvider<bool>((ref) => false);
final alumniMentorshipErrorProvider = StateProvider<bool>((ref) => false);
final alumniMentorshipEmptyProvider = StateProvider<bool>((ref) => false);
final alumniMentorshipFilterProvider = StateProvider<int>((ref) => 0);

final alumniMentorshipFutureProvider = FutureProvider<PaginatedResult<MentorshipPair>>((ref) async {
return ref.read(alumniRepositoryProvider).getMentorshipPairs(query: ref.watch(repositoryQueryProvider));
});

final alumniMentorshipProvider = Provider<List<MentorshipPair>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniMentorshipFutureProvider),
    manualLoading: ref.watch(alumniMentorshipLoadingProvider), manualError: ref.watch(alumniMentorshipErrorProvider), manualEmpty: ref.watch(alumniMentorshipEmptyProvider),
  )?.items ?? const [];
});

final alumniFilteredMentorshipProvider = Provider<List<MentorshipPair>>((ref) {
  final pairs = ref.watch(alumniMentorshipProvider);
  if (pairs == null) return const [];
  final filterIndex = ref.watch(alumniMentorshipFilterProvider);
  return switch (filterIndex) {
    1 => pairs.where((p) => p.status == MentorshipStatus.active).toList(),
    2 => pairs.where((p) => p.status == MentorshipStatus.pending).toList(),
    3 => pairs.where((p) => p.status == MentorshipStatus.completed).toList(),
    _ => pairs,
  };
});

// AL-08 Reports
final alumniReportsLoadingProvider = StateProvider<bool>((ref) => false);
final alumniReportsErrorProvider = StateProvider<bool>((ref) => false);
final alumniReportsEmptyProvider = StateProvider<bool>((ref) => false);

final alumniReportsFutureProvider = FutureProvider<AlumniReportsData>((ref) async {
return await ref.read(alumniRepositoryProvider).getReports(query: ref.watch(repositoryQueryProvider));
});

final alumniReportsProvider = Provider<AlumniReportsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniReportsFutureProvider),
    manualLoading: ref.watch(alumniReportsLoadingProvider), manualError: ref.watch(alumniReportsErrorProvider), manualEmpty: ref.watch(alumniReportsEmptyProvider),
  );
});

// AL-09 Settings
final alumniSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final alumniSettingsErrorProvider = StateProvider<bool>((ref) => false);

final alumniSettingsFutureProvider = FutureProvider<AlumniSettingsData>((ref) async {
return await ref.read(alumniRepositoryProvider).getSettings(query: ref.watch(repositoryQueryProvider));
});

final alumniSettingsProvider = Provider<AlumniSettingsData?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(alumniSettingsFutureProvider),
    manualLoading: ref.watch(alumniSettingsLoadingProvider), manualError: ref.watch(alumniSettingsErrorProvider), manualEmpty: false,
  );
});
