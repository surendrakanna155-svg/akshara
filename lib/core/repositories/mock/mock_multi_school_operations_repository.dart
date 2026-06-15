import '../../../features/multi_school/multi_school_models.dart';
import '../interfaces/multi_school_operations_repository.dart';
import '../repository_query.dart';

class MockMultiSchoolOperationsRepository
    implements MultiSchoolOperationsRepository {
  final List<SchoolLifecycleRecord> _schools = [
    SchoolLifecycleRecord(
      schoolId: 'sch_101',
      schoolName: 'Akshara Green Valley',
      status: SchoolLifecycleStatus.active,
      planName: 'Enterprise',
      region: 'Bengaluru',
      healthScore: const SchoolHealthScore(
        schoolId: 'sch_101',
        score: 88,
        band: 'Healthy',
        factors: ['Attendance stable', 'Fee collection on track'],
      ),
      studentsCount: 2140,
      staffCount: 172,
      updatedAt: DateTime(2026, 6, 14, 10, 0),
    ),
    SchoolLifecycleRecord(
      schoolId: 'sch_102',
      schoolName: 'Akshara City Central',
      status: SchoolLifecycleStatus.trial,
      planName: 'Growth',
      region: 'Hyderabad',
      healthScore: const SchoolHealthScore(
        schoolId: 'sch_102',
        score: 63,
        band: 'Watch',
        factors: ['Onboarding 60% complete', 'Low parent app activation'],
      ),
      studentsCount: 890,
      staffCount: 76,
      updatedAt: DateTime(2026, 6, 13, 14, 15),
    ),
    SchoolLifecycleRecord(
      schoolId: 'sch_103',
      schoolName: 'Akshara Horizon Campus',
      status: SchoolLifecycleStatus.churnRisk,
      planName: 'Growth',
      region: 'Chennai',
      healthScore: const SchoolHealthScore(
        schoolId: 'sch_103',
        score: 42,
        band: 'Critical',
        factors: ['Usage drop 35%', 'Open support escalations'],
      ),
      studentsCount: 1280,
      staffCount: 101,
      updatedAt: DateTime(2026, 6, 14, 8, 45),
    ),
  ];

  final List<PortfolioAlert> _alerts = [
    PortfolioAlert(
      id: 'msa_alert_1',
      title: 'Activation lag',
      message: 'Parent app activation below 30% for Akshara City Central.',
      severity: 'medium',
      schoolId: 'sch_102',
      schoolName: 'Akshara City Central',
      createdAt: DateTime(2026, 6, 14, 9, 0),
    ),
    PortfolioAlert(
      id: 'msa_alert_2',
      title: 'Churn signal',
      message: 'Usage and engagement trends indicate churn risk.',
      severity: 'high',
      schoolId: 'sch_103',
      schoolName: 'Akshara Horizon Campus',
      createdAt: DateTime(2026, 6, 14, 9, 30),
    ),
  ];

  final List<PortfolioAction> _actions = [
    PortfolioAction(
      id: 'msa_action_1',
      title: 'Schedule executive review',
      description: 'Book QBR with Akshara Horizon Campus leadership.',
      schoolId: 'sch_103',
      schoolName: 'Akshara Horizon Campus',
      dueAt: DateTime(2026, 6, 20),
    ),
    PortfolioAction(
      id: 'msa_action_2',
      title: 'Complete onboarding checklist',
      description: 'Finalize integrations and role setup.',
      schoolId: 'sch_102',
      schoolName: 'Akshara City Central',
      dueAt: DateTime(2026, 6, 18),
    ),
  ];

  final Map<String, SchoolOnboardingDraft> _drafts = {};

  @override
  Future<SchoolPortfolioDashboard> getPortfolioDashboard({
    required RepositoryQuery query,
  }) async {
    return SchoolPortfolioDashboard(
      kpis: [
        PortfolioKpi(
          id: 'total_schools',
          label: 'Total Schools',
          value: _schools.length.toString(),
          deltaLabel: '+1 this month',
          trend: 'up',
        ),
        PortfolioKpi(
          id: 'active_schools',
          label: 'Active',
          value: _schools
              .where((s) => s.status == SchoolLifecycleStatus.active)
              .length
              .toString(),
        ),
        PortfolioKpi(
          id: 'churn_risk',
          label: 'Churn Risk',
          value: _schools
              .where((s) => s.status == SchoolLifecycleStatus.churnRisk)
              .length
              .toString(),
          trend: 'down',
        ),
      ],
      alerts:
          _alerts.where((alert) => !alert.dismissed).toList(growable: false),
      schools: List<SchoolLifecycleRecord>.unmodifiable(_schools),
      pendingActions:
          _actions.where((action) => !action.completed).toList(growable: false),
    );
  }

  @override
  Future<List<SchoolLifecycleRecord>> listSchools({
    required RepositoryQuery query,
    SchoolLifecycleStatus? status,
  }) async {
    return _schools
        .where((school) => status == null || school.status == status)
        .toList(growable: false);
  }

  @override
  Future<SchoolHealthScore> getSchoolHealth({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    return _schools
        .firstWhere((school) => school.schoolId == schoolId)
        .healthScore;
  }

  @override
  Future<SchoolOnboardingDraft> createOnboardingDraft({
    required RepositoryQuery query,
    required SchoolOnboardingDraft draft,
  }) async {
    final now = DateTime.now();
    final persisted = draft.copyWith(updatedAt: now);
    _drafts[persisted.id] = persisted;
    return persisted;
  }

  @override
  Future<SchoolLifecycleRecord> submitOnboarding({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final draft = _drafts[draftId];
    if (draft == null) throw StateError('Onboarding draft not found: $draftId');

    final status = draft.activateNow
        ? SchoolLifecycleStatus.active
        : SchoolLifecycleStatus.trial;
    final school = SchoolLifecycleRecord(
      schoolId: 'sch_${100 + _schools.length + 1}',
      schoolName: draft.schoolName,
      status: status,
      planName: draft.planName,
      region: draft.country,
      healthScore: SchoolHealthScore(
        schoolId: draft.id,
        score: status == SchoolLifecycleStatus.active ? 74 : 58,
        band: status == SchoolLifecycleStatus.active ? 'Healthy' : 'Watch',
        factors: const ['Initial launch state'],
        lastEvaluatedAt: DateTime.now(),
      ),
      studentsCount: draft.studentCapacity ~/ 2,
      staffCount: 24,
      updatedAt: DateTime.now(),
    );
    _schools.add(school);
    return school;
  }

  @override
  Future<SchoolLifecycleRecord> activateSchool({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    return _updateSchoolStatus(
      schoolId: schoolId,
      status: SchoolLifecycleStatus.active,
    );
  }

  @override
  Future<SchoolLifecycleRecord> deactivateSchool({
    required RepositoryQuery query,
    required String schoolId,
    String? reason,
  }) async {
    return _updateSchoolStatus(
      schoolId: schoolId,
      status: SchoolLifecycleStatus.suspended,
    );
  }

  @override
  Future<List<PortfolioAlert>> listAlerts({
    required RepositoryQuery query,
  }) async {
    return _alerts.where((item) => !item.dismissed).toList(growable: false);
  }

  @override
  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) async {
    final index = _alerts.indexWhere((item) => item.id == alertId);
    if (index < 0) throw StateError('Alert not found: $alertId');
    final current = _alerts[index];
    _alerts[index] = PortfolioAlert(
      id: current.id,
      title: current.title,
      message: current.message,
      severity: current.severity,
      schoolId: current.schoolId,
      schoolName: current.schoolName,
      createdAt: current.createdAt,
      dismissed: true,
    );
  }

  @override
  Future<List<PortfolioAction>> listPendingActions({
    required RepositoryQuery query,
  }) async {
    return _actions.where((item) => !item.completed).toList(growable: false);
  }

  @override
  Future<PortfolioAction> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    final index = _actions.indexWhere((item) => item.id == actionId);
    if (index < 0) throw StateError('Action not found: $actionId');
    final current = _actions[index];
    final updated = PortfolioAction(
      id: current.id,
      title: current.title,
      description: current.description,
      schoolId: current.schoolId,
      schoolName: current.schoolName,
      dueAt: current.dueAt,
      completed: true,
    );
    _actions[index] = updated;
    return updated;
  }

  SchoolLifecycleRecord _updateSchoolStatus({
    required String schoolId,
    required SchoolLifecycleStatus status,
  }) {
    final index = _schools.indexWhere((school) => school.schoolId == schoolId);
    if (index < 0) throw StateError('School not found: $schoolId');
    final current = _schools[index];
    final updated = SchoolLifecycleRecord(
      schoolId: current.schoolId,
      schoolName: current.schoolName,
      status: status,
      planName: current.planName,
      region: current.region,
      healthScore: current.healthScore,
      studentsCount: current.studentsCount,
      staffCount: current.staffCount,
      updatedAt: DateTime.now(),
    );
    _schools[index] = updated;
    return updated;
  }
}
