import '../../interfaces/management_repository.dart';
import '../../repository_query.dart';
import '../../../../features/management/management_models.dart';
import '../../../../features/management/management_requests.dart';
import '../api_exception.dart';
import 'mapper/management_mapper.dart';
import 'remote/management_remote_datasource.dart';

/// API implementation of [ManagementRepository] — enabled via [managementApiEnabledProvider].
class ApiManagementRepository implements ManagementRepository {
  ApiManagementRepository({
    required ManagementRemoteDataSource remote,
    ManagementMapper mapper = const ManagementMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ManagementRemoteDataSource _remote;
  final ManagementMapper _mapper;

  @override
  Future<ManagementDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<ManagementAnalyticsData> getAnalytics({required RepositoryQuery query}) async {
    final dto = await _remote.fetchAnalytics(query: query);
    return _mapper.toAnalytics(dto);
  }

  @override
  Future<ManagementAdmissionsFunnelData> getAdmissionsFunnel({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAdmissionsFunnel(query: query);
    return _mapper.toAdmissionsFunnel(dto);
  }

  @override
  Future<ManagementFinancialHealthData> getFinancialHealth({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchFinancialHealth(query: query);
    return _mapper.toFinancialHealth(dto);
  }

  @override
  Future<ManagementAcademicHealthData> getAcademicHealth({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAcademicHealth(query: query);
    return _mapper.toAcademicHealth(dto);
  }

  @override
  Future<ManagementPerformanceData> getSchoolPerformance({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchSchoolPerformance(query: query);
    return _mapper.toSchoolPerformance(dto);
  }

  @override
  Future<ManagementTasksData> getTasksAndApprovals({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchTasksAndApprovals(query: query);
    return _mapper.toTasksAndApprovals(dto);
  }

  @override
  Future<ManagementSettingsData> getSettings({required RepositoryQuery query}) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }

  @override
  Future<ManagementApprovalItem> resolveManagementApproval({
    required RepositoryQuery query,
    required ResolveManagementApprovalRequest request,
  }) async {
    throw ApiNotConnectedException(
      'ManagementRepository',
      'resolveManagementApproval',
    );
  }
}
