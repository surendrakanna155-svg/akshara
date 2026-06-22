import '../../../features/platform/organization_builder/organization_builder_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/organization_builder_repository.dart';
import '../repository_query.dart';

class MockOrganizationBuilderRepository
    implements OrganizationBuilderRepository {
  MockOrganizationBuilderRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  static final List<VerticalPack> _packs = [
    const VerticalPack(
      id: 'pack_school',
      type: VerticalPackType.school,
      name: 'Education',
      description:
          'Students, classes, academic year — SIS, Finance, Education Suite.',
      primaryEntities: ['Students', 'Classes', 'Academic year'],
      moduleSeeds: ['SIS', 'Finance', 'Education Suite', 'Transport', 'Hostel'],
      dashboardFocus: 'Attendance, fees, risk, memories',
    ),
    const VerticalPack(
      id: 'pack_salon',
      type: VerticalPackType.salon,
      name: 'Salon (Velora)',
      description:
          'Clients, stylists, services — appointments, retail, staff scheduling.',
      primaryEntities: ['Clients', 'Stylists', 'Services'],
      moduleSeeds: ['Appointments', 'Retail inventory', 'Staff', 'Loyalty'],
      dashboardFocus: 'Chair utilization, revenue, loyalty',
      brandLabel: 'Velora',
    ),
    const VerticalPack(
      id: 'pack_hospital',
      type: VerticalPackType.hospital,
      name: 'Hospital',
      description:
          'Patients, departments, practitioners — billing, pharmacy, lab.',
      primaryEntities: ['Patients', 'Departments', 'Practitioners'],
      moduleSeeds: ['Appointments', 'Billing', 'Pharmacy', 'Lab', 'Supply'],
      dashboardFocus: 'Bed/OPD load, collections, inventory',
    ),
    const VerticalPack(
      id: 'pack_restaurant',
      type: VerticalPackType.restaurant,
      name: 'Restaurant',
      description:
          'Tables, menu, kitchen stations — orders, inventory, staff shifts.',
      primaryEntities: ['Tables', 'Menu', 'Kitchen stations'],
      moduleSeeds: ['Orders', 'Inventory', 'Staff shifts', 'POS'],
      dashboardFocus: 'Covers, ticket time, waste',
    ),
  ];

  final Map<String, InterviewDraft> _drafts = {
    'draft_existing_1': InterviewDraft(
      id: 'draft_existing_1',
      packId: 'pack_salon',
      organizationName: 'Velora Downtown',
      currentStep: 3,
      answers: {
        'identity_name': 'Velora Downtown',
        'identity_locations': '2',
        'scale_staff': '14',
        'scale_chairs': '10',
      },
      recommendations: const [
        InterviewRecommendation(
          id: 'rec_1',
          title: 'Enable loyalty module',
          detail: 'Salons with 2+ locations benefit from cross-branch loyalty.',
          confidence: 0.86,
        ),
      ],
      status: InterviewDraftStatus.inProgress,
      createdAt: DateTime(2026, 6, 10, 9, 0),
      updatedAt: DateTime(2026, 6, 12, 14, 30),
    ),
    'draft_existing_2': InterviewDraft(
      id: 'draft_existing_2',
      packId: 'pack_hospital',
      organizationName: 'Akshara Care Hospital',
      currentStep: 6,
      answers: {
        'identity_name': 'Akshara Care Hospital',
        'identity_departments': '8',
        'scale_beds': '120',
        'scale_doctors': '45',
        'modules_billing': 'true',
        'modules_pharmacy': 'true',
        'workflows_discharge': 'true',
        'channels_sms': 'true',
        'payments_insurance': 'true',
      },
      recommendations: const [
        InterviewRecommendation(
          id: 'rec_2',
          title: 'Insurance claim workflow',
          detail: 'Recommended for hospitals with 100+ beds.',
          confidence: 0.91,
        ),
      ],
      status: InterviewDraftStatus.readyForPreview,
      createdAt: DateTime(2026, 6, 8, 11, 0),
      updatedAt: DateTime(2026, 6, 14, 8, 0),
    ),
  };

  final Map<String, ProvisioningJob> _jobs = {};
  final Map<String, ConfigPreview> _previews = {};

  @override
  Future<List<VerticalPack>> listVerticalPacks({
    required RepositoryQuery query,
  }) async {
    return List<VerticalPack>.unmodifiable(_packs);
  }

  @override
  Future<List<InterviewDraft>> listInterviewDrafts({
    required RepositoryQuery query,
  }) async {
    final drafts = _drafts.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<InterviewDraft> getInterviewDraft({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final existing = _drafts[draftId];
    if (existing != null) return existing;

    final draft = InterviewDraft(
      id: draftId,
      packId: 'pack_school',
      organizationName: '',
      currentStep: 0,
      answers: const {},
      recommendations: const [],
      status: InterviewDraftStatus.inProgress,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _drafts[draftId] = draft;
    return draft;
  }

  @override
  Future<InterviewDraft> saveInterviewStep({
    required RepositoryQuery query,
    required String draftId,
    required int stepIndex,
    required Map<String, String> answers,
  }) async {
    final existing = _drafts[draftId];
    final packId = existing?.packId ?? answers['pack_id'] ?? 'pack_school';
    final pack = _packs.firstWhere((p) => p.id == packId);
    final orgName = answers['identity_name'] ??
        existing?.organizationName ??
        'New Organization';

    List<InterviewRecommendation> recommendations =
        existing?.recommendations ?? const [];

    try {
      final response = await _pipeline.complete(
        AiInferenceRequest(
          prompt:
              'Suggest one module or workflow recommendation for a ${pack.name} organization named "$orgName" at interview step $stepIndex.',
          taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
          systemPrompt:
              'You are an organization builder assistant. Return a single concise recommendation (title and detail) without PII.',
          context: {
            'packType': pack.type.value,
            'stepIndex': stepIndex,
            'answers': answers,
          },
        ),
      );
      if (response.content.isNotEmpty) {
        recommendations = [
          InterviewRecommendation(
            id: 'rec_ai_${DateTime.now().microsecondsSinceEpoch}',
            title: 'AI recommendation',
            detail: response.content.trim(),
            confidence: 0.82,
          ),
          ...recommendations,
        ];
      }
    } catch (_) {
      // AI recommendations are best-effort in mock mode.
    }

    final nextStep = stepIndex + 1;
    final status = nextStep >= 7
        ? InterviewDraftStatus.readyForPreview
        : InterviewDraftStatus.inProgress;

    final updated = (existing ??
            InterviewDraft(
              id: draftId,
              packId: packId,
              organizationName: orgName,
              currentStep: 0,
              answers: const {},
              recommendations: const [],
              status: InterviewDraftStatus.inProgress,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .copyWith(
      packId: packId,
      organizationName: orgName,
      currentStep: nextStep.clamp(0, 7),
      answers: {...?existing?.answers, ...answers},
      recommendations: recommendations,
      status: status,
      updatedAt: DateTime.now(),
    );

    _drafts[draftId] = updated;
    return updated;
  }

  @override
  Future<ConfigPreview> generatePreview({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final draft = await getInterviewDraft(query: query, draftId: draftId);
    final pack = _packs.firstWhere((p) => p.id == draft.packId);

    final modules = [
      for (final seed in pack.moduleSeeds)
        ConfigModuleItem(
          id: seed.toLowerCase().replaceAll(' ', '_'),
          name: seed,
          enabled: true,
          isNew: true,
        ),
      const ConfigModuleItem(
        id: kUniversalEmployeeModuleId,
        name: 'Universal Employee (FV-PLAT-01)',
        enabled: true,
        isNew: true,
      ),
      const ConfigModuleItem(
        id: 'auth',
        name: 'Auth & RBAC',
        enabled: true,
      ),
      const ConfigModuleItem(
        id: 'analytics',
        name: 'Analytics',
        enabled: true,
      ),
    ];

    final preview = ConfigPreview(
      draftId: draftId,
      organizationName: draft.organizationName,
      packId: draft.packId,
      modules: modules,
      roles: _rolesForPack(pack.type),
      widgets: _widgetsForPack(pack.type),
      workflows: _workflowsForPack(pack.type),
      generatedAt: DateTime.now(),
    );
    _previews[draftId] = preview;
    return preview;
  }

  @override
  Future<ProvisioningJob> startProvisioning({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    final draft = await getInterviewDraft(query: query, draftId: draftId);
    final jobId = 'job_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    final job = ProvisioningJob(
      id: jobId,
      draftId: draftId,
      organizationName: draft.organizationName,
      status: ProvisioningJobStatus.running,
      steps: [
        ProvisioningStep(
          id: 'step_org',
          label: 'Create organization',
          status: ProvisioningStepStatus.completed,
          startedAt: now,
          completedAt: now.add(const Duration(seconds: 2)),
        ),
        ProvisioningStep(
          id: 'step_branch',
          label: 'Create branch',
          status: ProvisioningStepStatus.running,
          startedAt: now.add(const Duration(seconds: 2)),
        ),
        const ProvisioningStep(
          id: 'step_roles',
          label: 'Seed roles',
          status: ProvisioningStepStatus.pending,
        ),
        const ProvisioningStep(
          id: 'step_permissions',
          label: 'Assign permissions',
          status: ProvisioningStepStatus.pending,
        ),
        const ProvisioningStep(
          id: 'step_seeds',
          label: 'Load seed data',
          status: ProvisioningStepStatus.pending,
        ),
        const ProvisioningStep(
          id: 'step_golive',
          label: 'Go live',
          status: ProvisioningStepStatus.pending,
        ),
      ],
      startedAt: now,
    );

    _jobs[jobId] = job;
    _drafts[draftId] = draft.copyWith(
      status: InterviewDraftStatus.provisioned,
      updatedAt: DateTime.now(),
    );

    _advanceJobAsync(jobId);
    return job;
  }

  void _advanceJobAsync(String jobId) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      _advanceJobStep(jobId);
    });
  }

  void _advanceJobStep(String jobId) {
    final job = _jobs[jobId];
    if (job == null || job.status == ProvisioningJobStatus.completed) return;

    final steps = List<ProvisioningStep>.from(job.steps);
    final runningIndex = steps.indexWhere(
      (s) => s.status == ProvisioningStepStatus.running,
    );
    if (runningIndex >= 0) {
      steps[runningIndex] = steps[runningIndex].copyWith(
        status: ProvisioningStepStatus.completed,
        completedAt: DateTime.now(),
      );
    }

    final nextPending = steps.indexWhere(
      (s) => s.status == ProvisioningStepStatus.pending,
    );
    if (nextPending >= 0) {
      steps[nextPending] = steps[nextPending].copyWith(
        status: ProvisioningStepStatus.running,
        startedAt: DateTime.now(),
      );
      _jobs[jobId] = job.copyWith(steps: steps);
      _advanceJobAsync(jobId);
      return;
    }

    _jobs[jobId] = job.copyWith(
      status: ProvisioningJobStatus.completed,
      steps: steps,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<ProvisioningJob> getProvisioningJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final job = _jobs[jobId];
    if (job == null) {
      throw StateError('Provisioning job not found: $jobId');
    }
    return job;
  }

  List<ConfigRoleItem> _rolesForPack(VerticalPackType type) {
    return switch (type) {
      VerticalPackType.school => const [
          ConfigRoleItem(id: 'principal', name: 'Principal', permissionCount: 48),
          ConfigRoleItem(id: 'teacher', name: 'Teacher', permissionCount: 22),
          ConfigRoleItem(id: 'parent', name: 'Parent', permissionCount: 12),
        ],
      VerticalPackType.salon => const [
          ConfigRoleItem(id: 'manager', name: 'Salon Manager', permissionCount: 36),
          ConfigRoleItem(id: 'stylist', name: 'Stylist', permissionCount: 18),
          ConfigRoleItem(id: 'reception', name: 'Reception', permissionCount: 14),
        ],
      VerticalPackType.hospital => const [
          ConfigRoleItem(id: 'admin', name: 'Hospital Admin', permissionCount: 52),
          ConfigRoleItem(id: 'doctor', name: 'Doctor', permissionCount: 28),
          ConfigRoleItem(id: 'nurse', name: 'Nurse', permissionCount: 20),
        ],
      VerticalPackType.restaurant => const [
          ConfigRoleItem(id: 'manager', name: 'Restaurant Manager', permissionCount: 34),
          ConfigRoleItem(id: 'chef', name: 'Chef', permissionCount: 16),
          ConfigRoleItem(id: 'server', name: 'Server', permissionCount: 10),
        ],
    };
  }

  List<ConfigWidgetItem> _widgetsForPack(VerticalPackType type) {
    return switch (type) {
      VerticalPackType.school => const [
          ConfigWidgetItem(
            id: 'school_health',
            role: 'Principal',
            widgetName: 'School Health',
          ),
          ConfigWidgetItem(
            id: 'fee_collection',
            role: 'Principal',
            widgetName: 'Fee Collection',
          ),
          ConfigWidgetItem(
            id: 'student_risk',
            role: 'Principal',
            widgetName: 'Student Risk',
          ),
          ConfigWidgetItem(
            id: 'attendance_risk',
            role: 'Principal',
            widgetName: 'Attendance Risk',
          ),
        ],
      VerticalPackType.salon => const [
          ConfigWidgetItem(
            id: 'chair_utilization',
            role: 'Salon Manager',
            widgetName: 'Chair utilization',
          ),
          ConfigWidgetItem(
            id: 'appointment_pipeline',
            role: 'Salon Manager',
            widgetName: 'Revenue by stylist',
          ),
        ],
      VerticalPackType.hospital => const [
          ConfigWidgetItem(
            id: 'bed_occupancy',
            role: 'Hospital Admin',
            widgetName: 'Bed occupancy',
          ),
          ConfigWidgetItem(
            id: 'opd_queue',
            role: 'Hospital Admin',
            widgetName: 'OPD queue',
          ),
        ],
      VerticalPackType.restaurant => const [
          ConfigWidgetItem(
            id: 'active_covers',
            role: 'Restaurant Manager',
            widgetName: 'Covers per hour',
          ),
          ConfigWidgetItem(
            id: 'ticket_time',
            role: 'Restaurant Manager',
            widgetName: 'Kitchen ticket time',
          ),
        ],
    };
  }

  List<ConfigWorkflowItem> _workflowsForPack(VerticalPackType type) {
    return switch (type) {
      VerticalPackType.school => const [
          ConfigWorkflowItem(
            id: 'wf1',
            name: 'Fee reminder',
            trigger: 'Due date - 3 days',
          ),
          ConfigWorkflowItem(
            id: 'wf2',
            name: 'Promotion approval',
            trigger: 'End of term',
          ),
        ],
      VerticalPackType.salon => const [
          ConfigWorkflowItem(
            id: 'wf1',
            name: 'Appointment confirm',
            trigger: '24h before slot',
          ),
          ConfigWorkflowItem(
            id: 'wf2',
            name: 'No-show follow-up',
            trigger: 'Missed appointment',
          ),
        ],
      VerticalPackType.hospital => const [
          ConfigWorkflowItem(
            id: 'wf1',
            name: 'Discharge checklist',
            trigger: 'Discharge order',
          ),
          ConfigWorkflowItem(
            id: 'wf2',
            name: 'Insurance claim',
            trigger: 'Billing finalized',
          ),
        ],
      VerticalPackType.restaurant => const [
          ConfigWorkflowItem(
            id: 'wf1',
            name: 'Order to kitchen',
            trigger: 'Order placed',
          ),
          ConfigWorkflowItem(
            id: 'wf2',
            name: 'Table ready alert',
            trigger: 'Order ready',
          ),
        ],
    };
  }
}
