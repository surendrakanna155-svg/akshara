import '../../interfaces/alumni_repository.dart';
import '../../repository_query.dart';
import '../../../../features/alumni/alumni_models.dart';
import 'mapper/alumni_mapper.dart';
import 'remote/alumni_remote_datasource.dart';

/// API implementation of [AlumniRepository] — enabled via [alumniApiEnabledProvider].
class ApiAlumniRepository implements AlumniRepository {
  ApiAlumniRepository({
    required AlumniRemoteDataSource remote,
    AlumniMapper mapper = const AlumniMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AlumniRemoteDataSource _remote;
  final AlumniMapper _mapper;

  @override
  Future<AlumniDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<List<AlumniRecord>> getAlumniRegistry({required RepositoryQuery query}) async {
    final dto = await _remote.fetchRegistry(query: query);
    return _mapper.toRegistry(dto);
  }

  @override
  Future<AlumniDetail?> getAlumniDetail({
    required RepositoryQuery query,
    required String alumniId,
  }) async {
    final dto = await _remote.fetchAlumniDetail(
      query: query,
      alumniId: alumniId,
    );
    return _mapper.toAlumniDetail(dto);
  }

  @override
  Future<List<AlumniEvent>> getEvents({required RepositoryQuery query}) async {
    final dto = await _remote.fetchEvents(query: query);
    return _mapper.toEvents(dto);
  }

  @override
  Future<List<AlumniDonation>> getDonations({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDonations(query: query);
    return _mapper.toDonations(dto);
  }

  @override
  Future<List<AlumniCampaign>> getCampaigns({required RepositoryQuery query}) async {
    final dto = await _remote.fetchCampaigns(query: query);
    return _mapper.toCampaigns(dto);
  }

  @override
  Future<List<MentorshipPair>> getMentorshipPairs({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMentorshipPairs(query: query);
    return _mapper.toMentorshipPairs(dto);
  }

  @override
  Future<AlumniReportsData> getReports({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<AlumniSettingsData> getSettings({required RepositoryQuery query}) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }
}
