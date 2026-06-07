// ignore_for_file: unused_field
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../interfaces/management_repository.dart';
import 'mapper/management_mapper.dart';
import '../../../../features/management/management_models.dart';
import 'remote/management_remote_datasource.dart';

/// API implementation of [ManagementRepository] — swap via [useApiRepositoriesProvider].
class ApiManagementRepository implements ManagementRepository {
  ApiManagementRepository({
    required ManagementRemoteDataSource remote,
    ManagementMapper mapper = const ManagementMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ManagementRemoteDataSource _remote;
  final ManagementMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiManagementRepository', method);
  }

  @override
  Future<ManagementDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<ManagementAnalyticsData> getAnalytics({required RepositoryQuery query}) async => _notConnected('getAnalytics');

  @override
  Future<ManagementAdmissionsFunnelData> getAdmissionsFunnel({required RepositoryQuery query}) async => _notConnected('getAdmissionsFunnel');

  @override
  Future<ManagementFinancialHealthData> getFinancialHealth({required RepositoryQuery query}) async => _notConnected('getFinancialHealth');

  @override
  Future<ManagementAcademicHealthData> getAcademicHealth({required RepositoryQuery query}) async => _notConnected('getAcademicHealth');

  @override
  Future<ManagementPerformanceData> getSchoolPerformance({required RepositoryQuery query}) async => _notConnected('getSchoolPerformance');

  @override
  Future<ManagementTasksData> getTasksAndApprovals({required RepositoryQuery query}) async => _notConnected('getTasksAndApprovals');

  @override
  Future<ManagementSettingsData> getSettings({required RepositoryQuery query}) async => _notConnected('getSettings');

}