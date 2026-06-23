import '../../../features/alumni/alumni_models.dart';
import '../../../features/alumni/alumni_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for alumni data access (mock or API).
abstract class AlumniRepository {
  Future<AlumniDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<AlumniRecord>> getAlumniRegistry({required RepositoryQuery query});
  Future<AlumniDetail?> getAlumniDetail({required RepositoryQuery query, required String alumniId});
  Future<PaginatedResult<AlumniEvent>> getEvents({required RepositoryQuery query});
  Future<PaginatedResult<AlumniDonation>> getDonations({required RepositoryQuery query});
  Future<PaginatedResult<AlumniCampaign>> getCampaigns({required RepositoryQuery query});
  Future<PaginatedResult<MentorshipPair>> getMentorshipPairs({required RepositoryQuery query});
  Future<AlumniReportsData> getReports({required RepositoryQuery query});
  Future<AlumniSettingsData> getSettings({required RepositoryQuery query});
  Future<AlumniRecord> addAlumni({
    required RepositoryQuery query,
    required AddAlumniRequest request,
  });
  Future<AlumniEvent> createEvent({
    required RepositoryQuery query,
    required CreateAlumniEventRequest request,
  });
  Future<AlumniCampaign> createCampaign({
    required RepositoryQuery query,
    required CreateAlumniCampaignRequest request,
  });
}
