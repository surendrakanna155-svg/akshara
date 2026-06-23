import '../../interfaces/alumni_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/alumni/alumni_models.dart';
import '../../../../features/alumni/alumni_requests.dart';
import '../api_exception.dart';
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
  Future<PaginatedResult<AlumniRecord>> getAlumniRegistry({required RepositoryQuery query}) async {
    final dto = await _remote.fetchRegistry(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toRegistry(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
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
  Future<PaginatedResult<AlumniEvent>> getEvents({required RepositoryQuery query}) async {
    final dto = await _remote.fetchEvents(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toEvents(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<AlumniDonation>> getDonations({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDonations(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toDonations(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<AlumniCampaign>> getCampaigns({required RepositoryQuery query}) async {
    final dto = await _remote.fetchCampaigns(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toCampaigns(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<MentorshipPair>> getMentorshipPairs({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMentorshipPairs(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toMentorshipPairs(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
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

  @override
  Future<AlumniRecord> addAlumni({
    required RepositoryQuery query,
    required AddAlumniRequest request,
  }) async {
    throw ApiNotConnectedException('AlumniRepository', 'addAlumni');
  }

  @override
  Future<AlumniEvent> createEvent({
    required RepositoryQuery query,
    required CreateAlumniEventRequest request,
  }) async {
    throw ApiNotConnectedException('AlumniRepository', 'createEvent');
  }

  @override
  Future<AlumniCampaign> createCampaign({
    required RepositoryQuery query,
    required CreateAlumniCampaignRequest request,
  }) async {
    throw ApiNotConnectedException('AlumniRepository', 'createCampaign');
  }

  @override
  Future<MentorshipPair> addMentorshipPair({
    required RepositoryQuery query,
    required AddMentorshipPairRequest request,
  }) async {
    throw ApiNotConnectedException('AlumniRepository', 'addMentorshipPair');
  }
}
