import '../../interfaces/control_center_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/platform/control_center/control_center_models.dart';
import '../../../../features/platform/control_center/control_center_requests.dart';
import '../api_exception.dart';
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

  @override
  Future<ControlCenterProvidersData> getProviders({required RepositoryQuery query}) async {
    final results = await Future.wait([
      _remote.fetchProvidersRaw(query: query),
      _remote.fetchUsageRaw(query: query),
      _remote.fetchFeaturesRaw(query: query),
    ]);
    final providersRaw = results[0] as Map<String, dynamic>;
    final usageRaw = results[1] as Map<String, dynamic>;
    final featuresRaw = results[2] as List<Map<String, dynamic>>;

    final providerItems = providersRaw['items'] as List? ?? [];
    final byCategoryRaw = usageRaw['byCategory'] as Map? ?? {};
    final byCategory = <String, PlatformUsageCategoryStats>{};
    for (final entry in byCategoryRaw.entries) {
      final v = entry.value as Map;
      byCategory[entry.key.toString()] = PlatformUsageCategoryStats(
        events: v['events'] as int? ?? 0,
        costInr: (v['costInr'] as num?)?.toDouble() ?? 0,
      );
    }

    return ControlCenterProvidersData(
      providers: [
        for (final p in providerItems)
          PlatformProviderConfig(
            id: (p as Map)['id'] as String? ?? '',
            providerCategory: p['providerCategory'] as String? ?? '',
            providerName: p['providerName'] as String? ?? '',
            hasCredential: p['hasCredential'] as bool? ?? false,
            isActive: p['isActive'] as bool? ?? false,
            isPrimary: p['isPrimary'] as bool? ?? false,
            healthStatus: p['healthStatus'] as String? ?? 'unknown',
          ),
      ],
      usage: PlatformUsageAnalytics(
        totalEvents: usageRaw['totalEvents'] as int? ?? 0,
        totalCostInr: (usageRaw['totalCostInr'] as num?)?.toDouble() ?? 0,
        byCategory: byCategory,
      ),
      features: [
        for (final f in featuresRaw)
          FeatureEnablement(
            schoolId: f['schoolId'] as String? ?? '',
            featureKey: f['featureKey'] as String? ?? '',
            enabled: f['enabled'] as bool? ?? false,
          ),
      ],
    );
  }

  @override
  Future<void> saveProvider({
    required RepositoryQuery query,
    required String providerCategory,
    required String providerName,
    String? credential,
    bool isActive = true,
    bool isPrimary = false,
  }) =>
      _remote.upsertProviderRaw(
        query: query,
        body: {
          'providerCategory': providerCategory,
          'providerName': providerName,
          if (credential != null) 'credential': credential,
          'isActive': isActive,
          'isPrimary': isPrimary,
        },
      );

  @override
  Future<void> setFeatureEnablement({
    required RepositoryQuery query,
    required String schoolId,
    required String featureKey,
    required bool enabled,
  }) =>
      _remote.setFeatureRaw(
        query: query,
        body: {'schoolId': schoolId, 'featureKey': featureKey, 'enabled': enabled},
      );

  @override
  Future<PlatformSchool> createSchool({
    required RepositoryQuery query,
    required CreateSchoolRequest request,
  }) async {
    throw ApiNotConnectedException('ControlCenterRepository', 'createSchool');
  }

  @override
  Future<CrmDeal> createLead({
    required RepositoryQuery query,
    required CreateCrmLeadRequest request,
  }) async {
    throw ApiNotConnectedException('ControlCenterRepository', 'createLead');
  }
}
