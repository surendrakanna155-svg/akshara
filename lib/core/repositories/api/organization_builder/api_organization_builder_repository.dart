import '../../../../features/organization_builder/organization_builder_models.dart';
import '../../interfaces/organization_builder_repository.dart';
import '../../repository_query.dart';
import 'remote/organization_builder_remote_datasource.dart';

class ApiOrganizationBuilderRepository
    implements OrganizationBuilderRepository {
  ApiOrganizationBuilderRepository({
    required OrganizationBuilderRemoteDataSource remote,
  }) : _remote = remote;

  final OrganizationBuilderRemoteDataSource _remote;

  @override
  Future<List<VerticalPack>> listVerticalPacks({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchPacks(query: query);
    return rows.map(_packFromMap).toList(growable: false);
  }

  @override
  Future<List<InterviewDraft>> listInterviewDrafts({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchInterviewDrafts(query: query);
    return rows.map(_draftFromMap).toList(growable: false);
  }

  @override
  Future<InterviewDraft> getInterviewDraft({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final data = await _remote.fetchInterviewDraft(
      query: query,
      draftId: draftId,
    );
    return _draftFromMap(data);
  }

  @override
  Future<InterviewDraft> saveInterviewStep({
    required RepositoryQuery query,
    required String draftId,
    required int stepIndex,
    required Map<String, String> answers,
  }) async {
    final data = await _remote.saveInterviewStep(
      query: query,
      draftId: draftId,
      body: {
        'stepIndex': stepIndex,
        'answers': answers,
      },
    );
    return _draftFromMap(data);
  }

  @override
  Future<ConfigPreview> generatePreview({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final data = await _remote.generatePreview(
      query: query,
      draftId: draftId,
    );
    return _previewFromMap(data);
  }

  @override
  Future<ProvisioningJob> startProvisioning({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final data = await _remote.startProvisioning(
      query: query,
      draftId: draftId,
    );
    return _jobFromMap(data);
  }

  @override
  Future<ProvisioningJob> getProvisioningJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final data = await _remote.fetchProvisioningJob(
      query: query,
      jobId: jobId,
    );
    return _jobFromMap(data);
  }

  VerticalPack _packFromMap(Map<String, dynamic> data) {
    return VerticalPack(
      id: data['id'] as String? ?? '',
      type: VerticalPackType.fromValue(
        data['type'] as String? ?? VerticalPackType.school.value,
      ),
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      primaryEntities: (data['primaryEntities'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      moduleSeeds: (data['moduleSeeds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      dashboardFocus: data['dashboardFocus'] as String? ?? '',
      brandLabel: data['brandLabel'] as String?,
    );
  }

  InterviewDraft _draftFromMap(Map<String, dynamic> data) {
    return InterviewDraft(
      id: data['id'] as String? ?? '',
      packId: data['packId'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      currentStep: data['currentStep'] as int? ?? 0,
      answers: (data['answers'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      recommendations: (data['recommendations'] as List<dynamic>? ?? const [])
          .map((item) => _recommendationFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      status: InterviewDraftStatus.fromValue(
        data['status'] as String? ?? InterviewDraftStatus.inProgress.value,
      ),
      createdAt: _parseDate(data['createdAt'] as String?) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt'] as String?) ?? DateTime.now(),
    );
  }

  InterviewRecommendation _recommendationFromMap(Map<String, dynamic> data) {
    return InterviewRecommendation(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  ConfigPreview _previewFromMap(Map<String, dynamic> data) {
    return ConfigPreview(
      draftId: data['draftId'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      packId: data['packId'] as String? ?? '',
      modules: (data['modules'] as List<dynamic>? ?? const [])
          .map((item) => _moduleFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      roles: (data['roles'] as List<dynamic>? ?? const [])
          .map((item) => _roleFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      widgets: (data['widgets'] as List<dynamic>? ?? const [])
          .map((item) => _widgetFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      workflows: (data['workflows'] as List<dynamic>? ?? const [])
          .map((item) => _workflowFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      generatedAt:
          _parseDate(data['generatedAt'] as String?) ?? DateTime.now(),
    );
  }

  ConfigModuleItem _moduleFromMap(Map<String, dynamic> data) {
    return ConfigModuleItem(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      enabled: data['enabled'] as bool? ?? false,
      isNew: data['isNew'] as bool? ?? false,
    );
  }

  ConfigRoleItem _roleFromMap(Map<String, dynamic> data) {
    return ConfigRoleItem(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      permissionCount: data['permissionCount'] as int? ?? 0,
    );
  }

  ConfigWidgetItem _widgetFromMap(Map<String, dynamic> data) {
    return ConfigWidgetItem(
      id: data['id'] as String? ?? '',
      role: data['role'] as String? ?? '',
      widgetName: data['widgetName'] as String? ?? '',
    );
  }

  ConfigWorkflowItem _workflowFromMap(Map<String, dynamic> data) {
    return ConfigWorkflowItem(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      trigger: data['trigger'] as String? ?? '',
    );
  }

  ProvisioningJob _jobFromMap(Map<String, dynamic> data) {
    return ProvisioningJob(
      id: data['id'] as String? ?? '',
      draftId: data['draftId'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      status: ProvisioningJobStatus.fromValue(
        data['status'] as String? ?? ProvisioningJobStatus.pending.value,
      ),
      steps: (data['steps'] as List<dynamic>? ?? const [])
          .map((item) => _stepFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      startedAt: _parseDate(data['startedAt'] as String?) ?? DateTime.now(),
      completedAt: _parseDate(data['completedAt'] as String?),
    );
  }

  ProvisioningStep _stepFromMap(Map<String, dynamic> data) {
    return ProvisioningStep(
      id: data['id'] as String? ?? '',
      label: data['label'] as String? ?? '',
      status: ProvisioningStepStatus.fromValue(
        data['status'] as String? ?? ProvisioningStepStatus.pending.value,
      ),
      startedAt: _parseDate(data['startedAt'] as String?),
      completedAt: _parseDate(data['completedAt'] as String?),
      error: data['error'] as String?,
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
