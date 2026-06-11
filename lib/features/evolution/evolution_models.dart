class SetupWizardSession {
  const SetupWizardSession({
    required this.id,
    required this.status,
    required this.currentStep,
    required this.inputs,
    required this.recommendations,
    required this.warnings,
    required this.missingItems,
    required this.steps,
  });

  final String id;
  final String status;
  final String currentStep;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> recommendations;
  final List<String> warnings;
  final List<String> missingItems;
  final List<String> steps;
}

class WidgetDefinition {
  const WidgetDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.requiredPermission,
    this.description,
    this.defaultWidth = 1,
    this.defaultHeight = 1,
  });

  final String id;
  final String title;
  final String category;
  final String requiredPermission;
  final String? description;
  final int defaultWidth;
  final int defaultHeight;
}

class DashboardWidgetPlacement {
  const DashboardWidgetPlacement({
    required this.widgetId,
    required this.order,
    required this.visible,
    required this.width,
    required this.height,
  });

  final String widgetId;
  final int order;
  final bool visible;
  final int width;
  final int height;

  DashboardWidgetPlacement copyWith({int? order, bool? visible}) {
    return DashboardWidgetPlacement(
      widgetId: widgetId,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      width: width,
      height: height,
    );
  }
}

class WidgetLiveData {
  const WidgetLiveData({
    required this.widgetId,
    required this.title,
    required this.value,
    required this.summary,
    this.metrics = const {},
    this.alerts = const [],
    this.refreshedAt,
    this.permissionDenied = false,
  });

  final String widgetId;
  final String title;
  final String value;
  final String summary;
  final Map<String, dynamic> metrics;
  final List<String> alerts;
  final String? refreshedAt;
  final bool permissionDenied;
}

class TeacherAssistantInsights {
  const TeacherAssistantInsights({
    required this.riskStudents,
    required this.weakTopics,
    required this.homeworkConcerns,
    required this.suggestedActions,
    required this.lessonPlanSuggestions,
    required this.parentMeetingSummaries,
    this.lessonHistory = const [],
    this.interventionEffectiveness = const [],
    this.scopedClassName,
  });

  final List<Map<String, dynamic>> riskStudents;
  final List<String> weakTopics;
  final List<String> homeworkConcerns;
  final List<String> suggestedActions;
  final List<String> lessonPlanSuggestions;
  final List<String> parentMeetingSummaries;
  final List<Map<String, dynamic>> lessonHistory;
  final List<Map<String, dynamic>> interventionEffectiveness;
  final String? scopedClassName;
}

class TeacherIntervention {
  const TeacherIntervention({
    required this.id,
    required this.studentId,
    required this.interventionType,
    required this.status,
    required this.priority,
    required this.title,
    this.notes,
    this.followUpAt,
  });

  final String id;
  final String studentId;
  final String interventionType;
  final String status;
  final String priority;
  final String title;
  final String? notes;
  final String? followUpAt;
}

class ParentInsightSnapshot {
  const ParentInsightSnapshot({
    required this.id,
    required this.period,
    required this.language,
    required this.progressSummary,
    required this.strengths,
    required this.weaknesses,
    required this.attendanceInsights,
    required this.homeworkInsights,
    required this.improvementSuggestions,
    required this.teacherRemarksSummary,
    this.printable = true,
    this.voiceReady = true,
  });

  final String id;
  final String period;
  final String language;
  final String progressSummary;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> attendanceInsights;
  final List<String> homeworkInsights;
  final List<String> improvementSuggestions;
  final String teacherRemarksSummary;
  final bool printable;
  final bool voiceReady;
}

class PrincipalCommandCenter {
  const PrincipalCommandCenter({
    required this.topPriorities,
    required this.executiveSummary,
    required this.actionRecommendations,
    required this.monthlyImprovement,
    required this.riskOverview,
    required this.widgets,
    this.priorityEngineScore,
  });

  final List<Map<String, dynamic>> topPriorities;
  final String executiveSummary;
  final List<String> actionRecommendations;
  final List<String> monthlyImprovement;
  final Map<String, dynamic> riskOverview;
  final Map<String, dynamic> widgets;
  final int? priorityEngineScore;
}

class GrowthFunnel {
  const GrowthFunnel({
    required this.stages,
    required this.campaignAttribution,
    required this.sourceAttribution,
    required this.convertedCount,
    required this.totalInquiries,
  });

  final List<Map<String, dynamic>> stages;
  final List<Map<String, dynamic>> campaignAttribution;
  final List<Map<String, dynamic>> sourceAttribution;
  final int convertedCount;
  final int totalInquiries;
}

class OperationsActionItem {
  const OperationsActionItem({
    required this.id,
    required this.module,
    required this.title,
    required this.severity,
    required this.actionType,
  });

  final String id;
  final String module;
  final String title;
  final String severity;
  final String actionType;
}

class GrowthDashboard {
  const GrowthDashboard({
    required this.campaigns,
    required this.inquiries,
    required this.conversionRate,
    required this.totalInquiries,
    required this.activeCampaigns,
  });

  final List<Map<String, dynamic>> campaigns;
  final List<Map<String, dynamic>> inquiries;
  final int conversionRate;
  final int totalInquiries;
  final int activeCampaigns;
}

class GrowthCampaign {
  const GrowthCampaign({
    required this.id,
    required this.name,
    required this.channel,
    required this.status,
    this.budgetInr,
  });

  final String id;
  final String name;
  final String channel;
  final String status;
  final double? budgetInr;
}

class GrowthInquiry {
  const GrowthInquiry({
    required this.id,
    required this.parentName,
    required this.source,
    required this.status,
    this.phone,
    this.gradeInterest,
    this.campaignId,
    this.leadId,
  });

  final String id;
  final String parentName;
  final String source;
  final String status;
  final String? phone;
  final String? gradeInterest;
  final String? campaignId;
  final String? leadId;
}
