// ignore_for_file: unused_field
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/alumni_repository.dart';
import '../../../../features/alumni/alumni_models.dart';
import 'mapper/alumni_mapper.dart';
import 'remote/alumni_remote_datasource.dart';

/// API implementation of [AlumniRepository] — swap via [useApiRepositoriesProvider].
class ApiAlumniRepository implements AlumniRepository {
  ApiAlumniRepository({
    required AlumniRemoteDataSource remote,
    AlumniMapper mapper = const AlumniMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AlumniRemoteDataSource _remote;
  final AlumniMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiAlumniRepository', method);
  }

  @override
  Future<AlumniDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<AlumniRecord>> getAlumniRegistry({required RepositoryQuery query}) async => _notConnected('getAlumniRegistry');

  @override
  Future<AlumniDetail?> getAlumniDetail({required RepositoryQuery query, required String alumniId}) async => _notConnected('getAlumniDetail');

  @override
  Future<List<AlumniEvent>> getEvents({required RepositoryQuery query}) async => _notConnected('getEvents');

  @override
  Future<List<AlumniDonation>> getDonations({required RepositoryQuery query}) async => _notConnected('getDonations');

  @override
  Future<List<AlumniCampaign>> getCampaigns({required RepositoryQuery query}) async => _notConnected('getCampaigns');

  @override
  Future<List<MentorshipPair>> getMentorshipPairs({required RepositoryQuery query}) async => _notConnected('getMentorshipPairs');

  @override
  Future<AlumniReportsData> getReports({required RepositoryQuery query}) async => _notConnected('getReports');

  @override
  Future<AlumniSettingsData> getSettings({required RepositoryQuery query}) async => _notConnected('getSettings');
}
