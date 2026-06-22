import '../../../../features/platform/multi_school/multi_school_models.dart';
import '../../interfaces/multi_school_operations_repository.dart';
import '../../repository_query.dart';
import 'remote/multi_school_operations_remote_datasource.dart';

class ApiMultiSchoolOperationsRepository
    implements MultiSchoolOperationsRepository {
  ApiMultiSchoolOperationsRepository({
    required MultiSchoolOperationsRemoteDataSource remote,
  }) : _remote = remote;

  final MultiSchoolOperationsRemoteDataSource _remote;

  @override
  Future<SchoolPortfolioDashboard> getPortfolioDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchPortfolioDashboard(query: query);
    return SchoolPortfolioDashboard(
      kpis: (data['kpis'] as List<dynamic>? ?? const [])
          .map((item) => _kpiFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      alerts: (data['alerts'] as List<dynamic>? ?? const [])
          .map((item) => _alertFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      schools: (data['schools'] as List<dynamic>? ?? const [])
          .map((item) => _schoolFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      pendingActions: (data['pendingActions'] as List<dynamic>? ?? const [])
          .map((item) => _actionFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<List<SchoolLifecycleRecord>> listSchools({
    required RepositoryQuery query,
    SchoolLifecycleStatus? status,
  }) async {
    final rows =
        await _remote.fetchSchools(query: query, status: status?.value);
    return rows.map(_schoolFromMap).toList(growable: false);
  }

  @override
  Future<SchoolHealthScore> getSchoolHealth({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    final data =
        await _remote.fetchSchoolHealth(query: query, schoolId: schoolId);
    return _healthFromMap(data);
  }

  @override
  Future<SchoolOnboardingDraft> createOnboardingDraft({
    required RepositoryQuery query,
    required SchoolOnboardingDraft draft,
  }) async {
    final payload = {
      'id': draft.id,
      'schoolName': draft.schoolName,
      'contactName': draft.contactName,
      'contactEmail': draft.contactEmail,
      'planName': draft.planName,
      'country': draft.country,
      'studentCapacity': draft.studentCapacity,
      'activateNow': draft.activateNow,
    };
    final data =
        await _remote.createOnboardingDraft(query: query, body: payload);
    return _draftFromMap(data);
  }

  @override
  Future<SchoolLifecycleRecord> submitOnboarding({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final data = await _remote.submitOnboarding(query: query, draftId: draftId);
    return _schoolFromMap(data);
  }

  @override
  Future<SchoolLifecycleRecord> activateSchool({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    final data = await _remote.activateSchool(query: query, schoolId: schoolId);
    return _schoolFromMap(data);
  }

  @override
  Future<SchoolLifecycleRecord> deactivateSchool({
    required RepositoryQuery query,
    required String schoolId,
    String? reason,
  }) async {
    final data = await _remote.deactivateSchool(
      query: query,
      schoolId: schoolId,
      reason: reason,
    );
    return _schoolFromMap(data);
  }

  @override
  Future<List<PortfolioAlert>> listAlerts({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchAlerts(query: query);
    return rows.map(_alertFromMap).toList(growable: false);
  }

  @override
  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) {
    return _remote.dismissAlert(query: query, alertId: alertId);
  }

  @override
  Future<List<PortfolioAction>> listPendingActions({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchPendingActions(query: query);
    return rows.map(_actionFromMap).toList(growable: false);
  }

  @override
  Future<PortfolioAction> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    final data = await _remote.completeAction(query: query, actionId: actionId);
    return _actionFromMap(data);
  }

  PortfolioKpi _kpiFromMap(Map<String, dynamic> data) {
    return PortfolioKpi(
      id: data['id'] as String? ?? '',
      label: data['label'] as String? ?? '',
      value: data['value'] as String? ?? '',
      deltaLabel: data['deltaLabel'] as String?,
      trend: data['trend'] as String?,
    );
  }

  SchoolHealthScore _healthFromMap(Map<String, dynamic> data) {
    return SchoolHealthScore(
      schoolId: data['schoolId'] as String? ?? '',
      score: data['score'] as int? ?? 0,
      band: data['band'] as String? ?? 'Unknown',
      factors: (data['factors'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      lastEvaluatedAt: _parseDate(data['lastEvaluatedAt'] as String?),
    );
  }

  SchoolLifecycleRecord _schoolFromMap(Map<String, dynamic> data) {
    return SchoolLifecycleRecord(
      schoolId: data['schoolId'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      status: SchoolLifecycleStatus.fromValue(
        data['status'] as String? ?? SchoolLifecycleStatus.trial.value,
      ),
      planName: data['planName'] as String? ?? '',
      region: data['region'] as String? ?? '',
      healthScore: _healthFromMap(
        (data['healthScore'] as Map<String, dynamic>?) ??
            <String, dynamic>{'schoolId': data['schoolId']},
      ),
      studentsCount: data['studentsCount'] as int? ?? 0,
      staffCount: data['staffCount'] as int? ?? 0,
      updatedAt: _parseDate(data['updatedAt'] as String?) ?? DateTime.now(),
    );
  }

  PortfolioAlert _alertFromMap(Map<String, dynamic> data) {
    return PortfolioAlert(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      severity: data['severity'] as String? ?? 'low',
      schoolId: data['schoolId'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      createdAt: _parseDate(data['createdAt'] as String?) ?? DateTime.now(),
      dismissed: data['dismissed'] as bool? ?? false,
    );
  }

  PortfolioAction _actionFromMap(Map<String, dynamic> data) {
    return PortfolioAction(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      schoolId: data['schoolId'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      dueAt: _parseDate(data['dueAt'] as String?) ?? DateTime.now(),
      completed: data['completed'] as bool? ?? false,
    );
  }

  SchoolOnboardingDraft _draftFromMap(Map<String, dynamic> data) {
    return SchoolOnboardingDraft(
      id: data['id'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      contactName: data['contactName'] as String? ?? '',
      contactEmail: data['contactEmail'] as String? ?? '',
      planName: data['planName'] as String? ?? '',
      country: data['country'] as String? ?? '',
      studentCapacity: data['studentCapacity'] as int? ?? 0,
      activateNow: data['activateNow'] as bool? ?? false,
      createdAt: _parseDate(data['createdAt'] as String?) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt'] as String?) ?? DateTime.now(),
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
