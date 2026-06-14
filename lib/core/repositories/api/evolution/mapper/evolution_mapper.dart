import '../../../../../features/evolution/evolution_models.dart';

class EvolutionMapper {
  const EvolutionMapper();

  SetupWizardSession toSetupWizardSession(Map<String, dynamic> json) {
    return SetupWizardSession(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'in_progress',
      currentStep: json['currentStep'] as String? ?? 'school_profile',
      inputs: _map(json['inputs']),
      recommendations: _map(json['recommendations']),
      warnings: _stringList(json['warnings']),
      missingItems: _stringList(json['missingItems'] ?? json['missing_items']),
      steps: _stringList(json['steps']),
    );
  }

  WidgetDefinition toWidgetDefinition(Map<String, dynamic> json) {
    return WidgetDefinition(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      requiredPermission: json['requiredPermission'] as String? ??
          json['required_permission'] as String? ??
          'viewAnalytics',
      description: json['description'] as String?,
      defaultWidth: json['defaultWidth'] as int? ?? json['default_width'] as int? ?? 1,
      defaultHeight: json['defaultHeight'] as int? ?? json['default_height'] as int? ?? 1,
    );
  }

  DashboardWidgetPlacement toDashboardPlacement(Map<String, dynamic> json) {
    return DashboardWidgetPlacement(
      widgetId: json['widgetId'] as String? ?? json['widget_id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      visible: json['visible'] as bool? ?? true,
      width: json['width'] as int? ?? 1,
      height: json['height'] as int? ?? 1,
    );
  }

  List<DashboardWidgetPlacement> toDashboardLayout(Map<String, dynamic> json) {
    final layout = json['layout'];
    if (layout is! List) return const [];
    return [
      for (final item in layout)
        if (item is Map<String, dynamic>) toDashboardPlacement(item),
    ];
  }

  WidgetLiveData toWidgetLiveData(Map<String, dynamic> json) {
    return WidgetLiveData(
      widgetId: json['widgetId'] as String? ?? json['widget_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      value: json['value'] as String? ?? '—',
      summary: json['summary'] as String? ?? '',
      metrics: _map(json['metrics']),
      alerts: _stringList(json['alerts']),
      refreshedAt: json['refreshedAt'] as String? ?? json['refreshed_at'] as String?,
      permissionDenied: json['permissionDenied'] as bool? ?? json['permission_denied'] as bool? ?? false,
    );
  }

  Map<String, WidgetLiveData> toWidgetDataMap(Map<String, dynamic> json) {
    final widgets = json['widgets'];
    if (widgets is! Map) return const {};
    return {
      for (final entry in widgets.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: toWidgetLiveData(entry.value as Map<String, dynamic>),
    };
  }

  TeacherAssistantInsights toTeacherAssistantInsights(Map<String, dynamic> json) {
    return TeacherAssistantInsights(
      riskStudents: _mapList(json['riskStudents'] ?? json['risk_students']),
      weakTopics: _stringList(json['weakTopics'] ?? json['weak_topics']),
      homeworkConcerns: _stringList(json['homeworkConcerns'] ?? json['homework_concerns']),
      suggestedActions: _stringList(json['suggestedActions'] ?? json['suggested_actions']),
      lessonPlanSuggestions: _stringList(
        json['lessonPlanSuggestions'] ?? json['lesson_plan_suggestions'],
      ),
      parentMeetingSummaries: _stringList(
        json['parentMeetingSummaries'] ?? json['parent_meeting_summaries'],
      ),
      lessonHistory: _mapList(json['lessonHistory'] ?? json['lesson_history']),
      interventionEffectiveness: _mapList(
        json['interventionEffectiveness'] ?? json['intervention_effectiveness'],
      ),
      scopedClassName: json['scopedClassName'] as String? ?? json['scoped_class_name'] as String?,
    );
  }

  TeacherIntervention toTeacherIntervention(Map<String, dynamic> json) {
    return TeacherIntervention(
      id: json['id'] as String,
      studentId: json['studentId'] as String? ?? json['student_id'] as String? ?? '',
      interventionType: json['interventionType'] as String? ?? json['intervention_type'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      followUpAt: json['followUpAt'] as String? ?? json['follow_up_at'] as String?,
    );
  }

  ParentInsightSnapshot toParentInsightSnapshot(Map<String, dynamic> json) {
    return ParentInsightSnapshot(
      id: json['id'] as String? ?? '',
      period: json['period'] as String? ?? 'weekly',
      language: json['language'] as String? ?? 'english',
      progressSummary: json['progressSummary'] as String? ?? json['progress_summary'] as String? ?? '',
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      attendanceInsights: _stringList(json['attendanceInsights'] ?? json['attendance_insights']),
      homeworkInsights: _stringList(json['homeworkInsights'] ?? json['homework_insights']),
      improvementSuggestions: _stringList(
        json['improvementSuggestions'] ?? json['improvement_suggestions'],
      ),
      teacherRemarksSummary: json['teacherRemarksSummary'] as String? ??
          json['teacher_remarks_summary'] as String? ??
          '',
      printable: json['printable'] as bool? ?? true,
      voiceReady: json['voiceReady'] as bool? ?? json['voice_ready'] as bool? ?? true,
    );
  }

  PrincipalCommandCenter toPrincipalCommandCenter(Map<String, dynamic> json) {
    return PrincipalCommandCenter(
      topPriorities: _mapList(json['topPriorities'] ?? json['top_priorities']),
      executiveSummary: json['executiveSummary'] as String? ?? json['executive_summary'] as String? ?? '',
      actionRecommendations: _stringList(
        json['actionRecommendations'] ?? json['action_recommendations'],
      ),
      monthlyImprovement: _stringList(json['monthlyImprovement'] ?? json['monthly_improvement']),
      riskOverview: _map(json['riskOverview'] ?? json['risk_overview']),
      widgets: _map(json['widgets']),
      priorityEngineScore: json['priorityEngineScore'] as int? ?? json['priority_engine_score'] as int?,
    );
  }

  GrowthDashboard toGrowthDashboard(Map<String, dynamic> json) {
    return GrowthDashboard(
      campaigns: _mapList(json['campaigns']),
      inquiries: _mapList(json['inquiries']),
      conversionRate: json['conversionRate'] as int? ?? json['conversion_rate'] as int? ?? 0,
      totalInquiries: json['totalInquiries'] as int? ?? json['total_inquiries'] as int? ?? 0,
      activeCampaigns: json['activeCampaigns'] as int? ?? json['active_campaigns'] as int? ?? 0,
    );
  }

  GrowthFunnel toGrowthFunnel(Map<String, dynamic> json) {
    return GrowthFunnel(
      stages: _mapList(json['stages']),
      campaignAttribution: _mapList(json['campaignAttribution'] ?? json['campaign_attribution']),
      sourceAttribution: _mapList(json['sourceAttribution'] ?? json['source_attribution']),
      convertedCount: json['convertedCount'] as int? ?? json['converted_count'] as int? ?? 0,
      totalInquiries: json['totalInquiries'] as int? ?? json['total_inquiries'] as int? ?? 0,
    );
  }

  GrowthCampaign toGrowthCampaign(Map<String, dynamic> json) {
    final budget = json['budgetInr'] ?? json['budget_inr'];
    return GrowthCampaign(
      id: json['id'] as String,
      name: json['name'] as String,
      channel: json['channel'] as String,
      status: json['status'] as String? ?? 'active',
      budgetInr: budget == null ? null : (budget as num).toDouble(),
      scheduledAt: json['scheduledAt'] as String? ?? json['scheduled_at'] as String?,
      audience: json['audience'] as String? ?? 'all',
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  GrowthInquiry toGrowthInquiry(Map<String, dynamic> json) {
    return GrowthInquiry(
      id: json['id'] as String,
      parentName: json['parentName'] as String? ?? json['parent_name'] as String? ?? '',
      source: json['source'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      phone: json['phone'] as String?,
      gradeInterest: json['gradeInterest'] as String? ?? json['grade_interest'] as String?,
      campaignId: json['campaignId'] as String? ?? json['campaign_id'] as String?,
      leadId: json['leadId'] as String? ?? json['lead_id'] as String?,
    );
  }

  OperationsActionItem toOperationsAction(Map<String, dynamic> json) {
    return OperationsActionItem(
      id: json['id'] as String? ?? '',
      module: json['module'] as String? ?? '',
      title: json['title'] as String? ?? '',
      severity: json['severity'] as String? ?? 'medium',
      actionType: json['actionType'] as String? ?? json['action_type'] as String? ?? 'review',
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [for (final item in value) item.toString()];
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) item
        else if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
