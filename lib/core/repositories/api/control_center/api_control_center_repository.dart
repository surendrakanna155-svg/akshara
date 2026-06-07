// ignore_for_file: unused_field
import '../../interfaces/control_center_repository.dart';
import '../api_exception.dart';
import '../../repository_query.dart';
import '../../../../features/control_center/control_center_models.dart';
import 'mapper/control_center_mapper.dart';
import 'remote/control_center_remote_datasource.dart';

/// API implementation of [ControlCenterRepository] — swap via [useApiRepositoriesProvider].
class ApiControlCenterRepository implements ControlCenterRepository {
  ApiControlCenterRepository({
    required ControlCenterRemoteDataSource remote,
    ControlCenterMapper mapper = const ControlCenterMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ControlCenterRemoteDataSource _remote;
  final ControlCenterMapper _mapper;

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiControlCenterRepository', method);
  }

  @override
  Future<ControlCenterDashboardData> getDashboard({required RepositoryQuery query}) async => _notConnected('getDashboard');

  @override
  Future<List<PlatformSchool>> getSchools({required RepositoryQuery query}) async => _notConnected('getSchools');

  @override
  Future<ControlCenterSubscriptionsData> getSubscriptions({required RepositoryQuery query}) async => _notConnected('getSubscriptions');

  @override
  Future<ControlCenterBillingData> getBilling({required RepositoryQuery query}) async => _notConnected('getBilling');

  @override
  Future<ControlCenterCrmData> getCrmPipeline({required RepositoryQuery query}) async => _notConnected('getCrmPipeline');

  @override
  Future<List<SupportTicket>> getSupportTickets({required RepositoryQuery query}) async => _notConnected('getSupportTickets');

  @override
  Future<ControlCenterSuccessData> getCustomerSuccess({required RepositoryQuery query}) async => _notConnected('getCustomerSuccess');

  @override
  Future<List<WhiteLabelConfig>> getWhiteLabelConfigs({required RepositoryQuery query}) async => _notConnected('getWhiteLabelConfigs');

  @override
  Future<ControlCenterAnalyticsData> getAnalytics({required RepositoryQuery query}) async => _notConnected('getAnalytics');

  @override
  Future<ControlCenterMonitoringData> getMonitoring({required RepositoryQuery query}) async => _notConnected('getMonitoring');

  @override
  Future<ControlCenterRolesData> getRoles({required RepositoryQuery query}) async => _notConnected('getRoles');

  @override
  Future<ControlCenterSettingsData> getSettings({required RepositoryQuery query}) async => _notConnected('getSettings');
}
