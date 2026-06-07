import '../../interfaces/control_center_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/control_center/control_center_models.dart';
import 'mapper/control_center_mapper.dart';
import 'remote/control_center_remote_datasource.dart';

/// API implementation of [ControlCenterRepository] — enabled via [controlCenterApiEnabledProvider].
class ApiControlCenterRepository implements ControlCenterRepository {
  ApiControlCenterRepository({
    required ControlCenterRemoteDataSource remote,
    ControlCenterMapper mapper = const ControlCenterMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ControlCenterRemoteDataSource _remote;
  final ControlCenterMapper _mapper;

  @override
  Future<ControlCenterDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<PlatformSchool>> getSchools({required RepositoryQuery query}) async {
    final dto = await _remote.fetchSchools(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toSchools(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<ControlCenterSubscriptionsData> getSubscriptions({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchSubscriptions(query: query);
    return _mapper.toSubscriptions(dto);
  }

  @override
  Future<ControlCenterBillingData> getBilling({required RepositoryQuery query}) async {
    final dto = await _remote.fetchBilling(query: query);
    return _mapper.toBilling(dto);
  }

  @override
  Future<ControlCenterCrmData> getCrmPipeline({required RepositoryQuery query}) async {
    final dto = await _remote.fetchCrmPipeline(query: query);
    return _mapper.toCrmPipeline(dto);
  }

  @override
  Future<PaginatedResult<SupportTicket>> getSupportTickets({required RepositoryQuery query}) async {
    final dto = await _remote.fetchSupportTickets(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toSupportTickets(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<ControlCenterSuccessData> getCustomerSuccess({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchCustomerSuccess(query: query);
    return _mapper.toCustomerSuccess(dto);
  }

  @override
  Future<PaginatedResult<WhiteLabelConfig>> getWhiteLabelConfigs({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchWhiteLabelConfigs(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toWhiteLabelConfigs(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<ControlCenterAnalyticsData> getAnalytics({required RepositoryQuery query}) async {
    final dto = await _remote.fetchAnalytics(query: query);
    return _mapper.toAnalytics(dto);
  }

  @override
  Future<ControlCenterMonitoringData> getMonitoring({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMonitoring(query: query);
    return _mapper.toMonitoring(dto);
  }

  @override
  Future<ControlCenterRolesData> getRoles({required RepositoryQuery query}) async {
    final dto = await _remote.fetchRoles(query: query);
    return _mapper.toRoles(dto);
  }

  @override
  Future<ControlCenterSettingsData> getSettings({required RepositoryQuery query}) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }
}
