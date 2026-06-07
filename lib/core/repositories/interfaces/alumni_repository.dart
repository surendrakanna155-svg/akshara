import '../../../features/alumni/alumni_models.dart';
import '../repository_query.dart';

/// Contract for alumni data access (mock or API).
abstract class AlumniRepository {
  Future<AlumniDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<AlumniRecord>> getAlumniRegistry({required RepositoryQuery query});
  Future<AlumniDetail?> getAlumniDetail({required RepositoryQuery query, required String alumniId});
  Future<List<AlumniEvent>> getEvents({required RepositoryQuery query});
  Future<List<AlumniDonation>> getDonations({required RepositoryQuery query});
  Future<List<AlumniCampaign>> getCampaigns({required RepositoryQuery query});
  Future<List<MentorshipPair>> getMentorshipPairs({required RepositoryQuery query});
  Future<AlumniReportsData> getReports({required RepositoryQuery query});
  Future<AlumniSettingsData> getSettings({required RepositoryQuery query});
}
