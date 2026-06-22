enum VerticalPackType {
  school('school'),
  salon('salon'),
  hospital('hospital'),
  restaurant('restaurant');

  const VerticalPackType(this.value);
  final String value;

  static VerticalPackType fromValue(String raw) {
    for (final type in VerticalPackType.values) {
      if (type.value == raw) return type;
    }
    return VerticalPackType.school;
  }
}

enum InterviewDraftStatus {
  inProgress('in_progress'),
  readyForPreview('ready_for_preview'),
  provisioned('provisioned');

  const InterviewDraftStatus(this.value);
  final String value;

  static InterviewDraftStatus fromValue(String raw) {
    for (final status in InterviewDraftStatus.values) {
      if (status.value == raw) return status;
    }
    return InterviewDraftStatus.inProgress;
  }
}

enum ProvisioningJobStatus {
  pending('pending'),
  running('running'),
  completed('completed'),
  failed('failed');

  const ProvisioningJobStatus(this.value);
  final String value;

  static ProvisioningJobStatus fromValue(String raw) {
    for (final status in ProvisioningJobStatus.values) {
      if (status.value == raw) return status;
    }
    return ProvisioningJobStatus.pending;
  }
}

enum ProvisioningStepStatus {
  pending('pending'),
  running('running'),
  completed('completed'),
  failed('failed'),
  skipped('skipped');

  const ProvisioningStepStatus(this.value);
  final String value;

  static ProvisioningStepStatus fromValue(String raw) {
    for (final status in ProvisioningStepStatus.values) {
      if (status.value == raw) return status;
    }
    return ProvisioningStepStatus.pending;
  }
}

/// FV-PLAT-01 Universal Employee — enabled as a module flag in org config.
const String kUniversalEmployeeModuleId = 'universal_employee';

class VerticalPack {
  const VerticalPack({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.primaryEntities,
    required this.moduleSeeds,
    required this.dashboardFocus,
    this.brandLabel,
  });

  final String id;
  final VerticalPackType type;
  final String name;
  final String description;
  final List<String> primaryEntities;
  final List<String> moduleSeeds;
  final String dashboardFocus;
  final String? brandLabel;
}

class OrganizationProfile {
  const OrganizationProfile({
    required this.id,
    required this.packId,
    required this.organizationName,
    required this.verticalType,
    required this.configVersion,
    required this.enabledModules,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packId;
  final String organizationName;
  final VerticalPackType verticalType;
  final int configVersion;
  final List<String> enabledModules;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class InterviewRecommendation {
  const InterviewRecommendation({
    required this.id,
    required this.title,
    required this.detail,
    required this.confidence,
  });

  final String id;
  final String title;
  final String detail;
  final double confidence;
}

class InterviewDraft {
  const InterviewDraft({
    required this.id,
    required this.packId,
    required this.organizationName,
    required this.currentStep,
    required this.answers,
    required this.recommendations,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packId;
  final String organizationName;
  final int currentStep;
  final Map<String, String> answers;
  final List<InterviewRecommendation> recommendations;
  final InterviewDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  InterviewDraft copyWith({
    String? packId,
    String? organizationName,
    int? currentStep,
    Map<String, String>? answers,
    List<InterviewRecommendation>? recommendations,
    InterviewDraftStatus? status,
    DateTime? updatedAt,
  }) {
    return InterviewDraft(
      id: id,
      packId: packId ?? this.packId,
      organizationName: organizationName ?? this.organizationName,
      currentStep: currentStep ?? this.currentStep,
      answers: answers ?? this.answers,
      recommendations: recommendations ?? this.recommendations,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConfigModuleItem {
  const ConfigModuleItem({
    required this.id,
    required this.name,
    required this.enabled,
    this.isNew = false,
  });

  final String id;
  final String name;
  final bool enabled;
  final bool isNew;
}

class ConfigRoleItem {
  const ConfigRoleItem({
    required this.id,
    required this.name,
    required this.permissionCount,
  });

  final String id;
  final String name;
  final int permissionCount;
}

class ConfigWidgetItem {
  const ConfigWidgetItem({
    required this.id,
    required this.role,
    required this.widgetName,
  });

  final String id;
  final String role;
  final String widgetName;
}

class ConfigWorkflowItem {
  const ConfigWorkflowItem({
    required this.id,
    required this.name,
    required this.trigger,
  });

  final String id;
  final String name;
  final String trigger;
}

class ConfigPreview {
  const ConfigPreview({
    required this.draftId,
    required this.organizationName,
    required this.packId,
    required this.modules,
    required this.roles,
    required this.widgets,
    required this.workflows,
    required this.generatedAt,
  });

  final String draftId;
  final String organizationName;
  final String packId;
  final List<ConfigModuleItem> modules;
  final List<ConfigRoleItem> roles;
  final List<ConfigWidgetItem> widgets;
  final List<ConfigWorkflowItem> workflows;
  final DateTime generatedAt;
}

class ProvisioningStep {
  const ProvisioningStep({
    required this.id,
    required this.label,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  final String id;
  final String label;
  final ProvisioningStepStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? error;

  ProvisioningStep copyWith({
    ProvisioningStepStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? error,
  }) {
    return ProvisioningStep(
      id: id,
      label: label,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
    );
  }
}

class ProvisioningJob {
  const ProvisioningJob({
    required this.id,
    required this.draftId,
    required this.organizationName,
    required this.status,
    required this.steps,
    required this.startedAt,
    this.completedAt,
  });

  final String id;
  final String draftId;
  final String organizationName;
  final ProvisioningJobStatus status;
  final List<ProvisioningStep> steps;
  final DateTime startedAt;
  final DateTime? completedAt;

  ProvisioningJob copyWith({
    ProvisioningJobStatus? status,
    List<ProvisioningStep>? steps,
    DateTime? completedAt,
  }) {
    return ProvisioningJob(
      id: id,
      draftId: draftId,
      organizationName: organizationName,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
