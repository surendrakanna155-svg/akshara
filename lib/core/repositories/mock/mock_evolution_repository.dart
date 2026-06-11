import '../../../features/evolution/evolution_models.dart';
import '../interfaces/evolution_repository.dart';
import '../repository_query.dart';

class MockEvolutionRepository implements EvolutionRepository {
  final List<TeacherIntervention> _interventions = [];
  final List<ParentInsightSnapshot> _insights = [];
  final Map<String, WidgetLiveData> _widgetCache = {};
  String? _parentLanguage;
  final List<GrowthCampaign> _campaigns = [
    const GrowthCampaign(
      id: 'camp_1',
      name: 'Summer Open Day',
      channel: 'walk_in',
      status: 'active',
      budgetInr: 25000,
    ),
  ];
  final List<GrowthInquiry> _inquiries = [
    const GrowthInquiry(
      id: 'inq_1',
      parentName: 'Lakshmi Rao',
      source: 'referral',
      status: 'new',
      phone: '+91 98765 43210',
      gradeInterest: 'Grade 1',
      campaignId: 'camp_1',
    ),
  ];

  List<DashboardWidgetPlacement> _layout = const [
    DashboardWidgetPlacement(widgetId: 'school_health', order: 0, visible: true, width: 2, height: 1),
    DashboardWidgetPlacement(widgetId: 'student_risk', order: 1, visible: true, width: 1, height: 1),
    DashboardWidgetPlacement(widgetId: 'fee_collection', order: 2, visible: true, width: 1, height: 1),
    DashboardWidgetPlacement(widgetId: 'attendance_risk', order: 3, visible: true, width: 1, height: 1),
  ];

  @override
  Future<SetupWizardSession> createSetupWizard({
    required RepositoryQuery query,
    Map<String, dynamic> inputs = const {},
  }) async {
    return SetupWizardSession(
      id: 'wizard_1',
      status: 'in_progress',
      currentStep: 'school_profile',
      inputs: inputs,
      recommendations: {
        'academicYear': '2026-27',
        'classes': inputs['grades'] ?? ['Grade 1', 'Grade 2'],
        'teacherStudentRatio': '1:20',
      },
      warnings: const ['Review fee model before go-live'],
      missingItems: const ['Teacher CSV import', 'Student CSV import'],
      steps: const [
        'school_profile', 'academic_year', 'classes', 'sections',
        'subjects', 'fee_structure', 'imports', 'timetable', 'review',
      ],
    );
  }

  @override
  Future<SetupWizardSession> advanceSetupWizard({
    required RepositoryQuery query,
    required String sessionId,
    required String step,
    Map<String, dynamic> inputs = const {},
    bool complete = false,
  }) async {
    return SetupWizardSession(
      id: sessionId,
      status: complete ? 'completed' : 'in_progress',
      currentStep: step,
      inputs: inputs,
      recommendations: {'academicYear': '2026-27', 'teacherStudentRatio': '1:18'},
      warnings: const [],
      missingItems: complete ? const [] : const ['Timetable publication'],
      steps: const [
        'school_profile', 'academic_year', 'classes', 'sections',
        'subjects', 'fee_structure', 'imports', 'timetable', 'review',
      ],
    );
  }

  @override
  Future<List<WidgetDefinition>> listWidgets({required RepositoryQuery query}) async {
    return const [
      WidgetDefinition(id: 'school_health', title: 'School Health', category: 'operations', requiredPermission: 'viewOperationsHub'),
      WidgetDefinition(id: 'student_risk', title: 'Student Risk', category: 'intelligence', requiredPermission: 'viewStudentRisk'),
      WidgetDefinition(id: 'fee_collection', title: 'Fee Collection', category: 'finance', requiredPermission: 'viewFinance'),
      WidgetDefinition(id: 'attendance_risk', title: 'Attendance Risk', category: 'intelligence', requiredPermission: 'viewStudentRisk'),
      WidgetDefinition(id: 'homework_summary', title: 'Homework Summary', category: 'academics', requiredPermission: 'viewHomeworkIntelligence'),
      WidgetDefinition(id: 'operations_summary', title: 'Operations Summary', category: 'operations', requiredPermission: 'viewOperationsHub'),
      WidgetDefinition(id: 'employee_workload', title: 'Employee Workload', category: 'hr', requiredPermission: 'viewEmployeeIntelligence'),
      WidgetDefinition(id: 'timetable_alerts', title: 'Timetable Alerts', category: 'operations', requiredPermission: 'viewAcademicTimetable'),
    ];
  }

  @override
  Future<List<DashboardWidgetPlacement>> getDashboardLayout({
    required RepositoryQuery query,
    String dashboardKey = 'default',
  }) async => List.from(_layout);

  @override
  Future<List<DashboardWidgetPlacement>> saveDashboardLayout({
    required RepositoryQuery query,
    required List<DashboardWidgetPlacement> layout,
    String dashboardKey = 'default',
  }) async {
    _layout = List.from(layout);
    return _layout;
  }

  @override
  Future<Map<String, WidgetLiveData>> getWidgetData({
    required RepositoryQuery query,
    List<String>? widgetIds,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _widgetCache.isNotEmpty) {
      if (widgetIds == null) return Map.from(_widgetCache);
      return {for (final id in widgetIds) id: _widgetCache[id]!};
    }
    final data = <String, WidgetLiveData>{
      'school_health': const WidgetLiveData(
        widgetId: 'school_health',
        title: 'School Health',
        value: '82',
        summary: 'Overall school health score',
        metrics: {'score': 82},
      ),
      'student_risk': const WidgetLiveData(
        widgetId: 'student_risk',
        title: 'Student Risk',
        value: '3',
        summary: 'High-risk students this week',
        metrics: {'high': 2, 'critical': 1},
      ),
      'fee_collection': const WidgetLiveData(
        widgetId: 'fee_collection',
        title: 'Fee Collection',
        value: '₹1.2L',
        summary: 'Collections today',
        metrics: {'count': 14},
      ),
      'attendance_risk': const WidgetLiveData(
        widgetId: 'attendance_risk',
        title: 'Attendance Risk',
        value: '5',
        summary: 'Students below 75% attendance',
      ),
      'homework_summary': const WidgetLiveData(
        widgetId: 'homework_summary',
        title: 'Homework Summary',
        value: '78%',
        summary: 'Average completion rate',
      ),
      'operations_summary': const WidgetLiveData(
        widgetId: 'operations_summary',
        title: 'Operations Summary',
        value: '4',
        summary: 'Pending operational actions',
      ),
      'employee_workload': const WidgetLiveData(
        widgetId: 'employee_workload',
        title: 'Employee Workload',
        value: '2',
        summary: 'Teachers with high workload',
      ),
      'timetable_alerts': const WidgetLiveData(
        widgetId: 'timetable_alerts',
        title: 'Timetable Alerts',
        value: '1',
        summary: 'Unresolved timetable conflicts',
      ),
    };
    _widgetCache
      ..clear()
      ..addAll(data);
    if (widgetIds == null) return data;
    return {for (final id in widgetIds) id: data[id]!};
  }

  @override
  Future<TeacherAssistantInsights> getTeacherAssistantInsights({
    required RepositoryQuery query,
    String? className,
  }) async {
    return TeacherAssistantInsights(
      riskStudents: [
        {
          'studentId': 'student_1',
          'studentName': 'Arjun Reddy',
          'className': className ?? 'Grade 8',
          'riskLevel': 'high',
          'topReason': 'Low attendance',
        },
      ],
      weakTopics: const ['Fractions', 'Grammar tenses'],
      homeworkConcerns: const ['Arjun Reddy: 55% completion'],
      suggestedActions: const ['Schedule doubt-clearing for weak performers'],
      lessonPlanSuggestions: const ['Start with 10-min recap of previous weak topic'],
      parentMeetingSummaries: const ['Discuss Arjun Reddy\'s low attendance with parents'],
      lessonHistory: const [
        {'date': '2026-06-01', 'topic': 'Fractions', 'outcome': 'needs_revision'},
      ],
      interventionEffectiveness: const [
        {'interventionType': 'academic', 'completed': 2, 'open': 1, 'effectiveness': 'moderate'},
      ],
      scopedClassName: className,
    );
  }

  @override
  Future<List<TeacherIntervention>> listInterventions({required RepositoryQuery query}) async =>
      List.from(_interventions);

  @override
  Future<String> createIntervention({
    required RepositoryQuery query,
    required String studentId,
    required String interventionType,
    required String title,
    String? notes,
    String priority = 'medium',
  }) async {
    final id = 'int_${_interventions.length + 1}';
    _interventions.add(TeacherIntervention(
      id: id,
      studentId: studentId,
      interventionType: interventionType,
      status: 'open',
      priority: priority,
      title: title,
      notes: notes,
    ));
    return id;
  }

  @override
  Future<ParentInsightSnapshot> generateParentInsights({
    required RepositoryQuery query,
    required String studentId,
    String period = 'weekly',
    String language = 'english',
  }) async {
    final snapshot = ParentInsightSnapshot(
      id: 'insight_${_insights.length + 1}',
      period: period,
      language: language,
      progressSummary: '$period summary for student ($language)',
      strengths: const ['Consistent participation'],
      weaknesses: const ['Time management during assessments'],
      attendanceInsights: const ['Attendance is 85% — on track'],
      homeworkInsights: const ['Homework completion is 78% — good consistency'],
      improvementSuggestions: const ['Allocate 30 minutes daily for revision'],
      teacherRemarksSummary: 'Teachers note steady effort with room to improve.',
    );
    _insights.add(snapshot);
    return snapshot;
  }

  @override
  Future<List<ParentInsightSnapshot>> listParentInsights({
    required RepositoryQuery query,
    required String studentId,
  }) async => _insights;

  @override
  Future<String?> getParentLanguagePreference({
    required RepositoryQuery query,
    String? studentId,
  }) async =>
      _parentLanguage ?? 'english';

  @override
  Future<void> saveParentLanguagePreference({
    required RepositoryQuery query,
    required String language,
    String? studentId,
  }) async {
    _parentLanguage = language;
  }

  @override
  Future<PrincipalCommandCenter> getPrincipalCommandCenter({
    required RepositoryQuery query,
  }) async {
    return const PrincipalCommandCenter(
      topPriorities: [
        {'priority': 'Low attendance students', 'category': 'attendance', 'count': 3},
        {'priority': 'Critical-risk students', 'category': 'risk', 'count': 1},
      ],
      executiveSummary: 'Monthly Principal Command Summary — health 82/100',
      actionRecommendations: ['Review class risk dashboards weekly'],
      monthlyImprovement: ['School health score is 82/100.'],
      riskOverview: {'critical': 1, 'high': 2, 'medium': 4, 'total': 120},
      widgets: {'attendanceConcern': 3, 'feeOverdue': 5, 'overloadedTeachers': 2, 'decliningClasses': 0},
      priorityEngineScore: 82,
    );
  }

  @override
  Future<Map<String, dynamic>> queryPrincipalCommand({
    required RepositoryQuery query,
    required String queryText,
  }) async {
    return {
      'query': queryText,
      'intent': 'high_risk',
      'summary': '2 high-risk students',
      'count': 2,
      'items': [
        {'studentName': 'Arjun Reddy', 'riskLevel': 'high'},
      ],
    };
  }

  @override
  Future<GrowthFunnel> getGrowthFunnel({required RepositoryQuery query}) async {
    return GrowthFunnel(
      stages: const [
        {'stage': 'inquiry', 'count': 12},
        {'stage': 'contacted', 'count': 8},
        {'stage': 'converted', 'count': 3},
      ],
      campaignAttribution: const [
        {'campaign': 'Summer Open Day', 'inquiries': 5, 'converted': 2},
      ],
      sourceAttribution: const [
        {'source': 'referral', 'inquiries': 4, 'converted': 2},
        {'source': 'website', 'inquiries': 8, 'converted': 1},
      ],
      convertedCount: 3,
      totalInquiries: _inquiries.length,
    );
  }

  @override
  Future<GrowthDashboard> getGrowthDashboard({required RepositoryQuery query}) async {
    return GrowthDashboard(
      campaigns: _campaigns.map((c) => {'status': c.status, 'channel': c.channel, 'count': 1}).toList(),
      inquiries: _inquiries.map((i) => {'status': i.status, 'source': i.source, 'count': 1}).toList(),
      conversionRate: 25,
      totalInquiries: _inquiries.length,
      activeCampaigns: _campaigns.where((c) => c.status == 'active').length,
    );
  }

  @override
  Future<List<GrowthCampaign>> listGrowthCampaigns({required RepositoryQuery query}) async =>
      List.from(_campaigns);

  @override
  Future<List<GrowthInquiry>> listGrowthInquiries({required RepositoryQuery query}) async =>
      List.from(_inquiries);

  @override
  Future<String> createGrowthCampaign({
    required RepositoryQuery query,
    required String name,
    required String channel,
    double? budgetInr,
  }) async {
    final id = 'camp_${_campaigns.length + 1}';
    _campaigns.add(GrowthCampaign(id: id, name: name, channel: channel, status: 'active', budgetInr: budgetInr));
    return id;
  }

  @override
  Future<String> createGrowthInquiry({
    required RepositoryQuery query,
    required String parentName,
    required String source,
    String? phone,
    String? gradeInterest,
    String? campaignId,
  }) async {
    final id = 'inq_${_inquiries.length + 1}';
    _inquiries.add(GrowthInquiry(
      id: id,
      parentName: parentName,
      source: source,
      status: 'new',
      phone: phone,
      gradeInterest: gradeInterest,
      campaignId: campaignId,
    ));
    return id;
  }

  @override
  Future<String> convertGrowthInquiry({
    required RepositoryQuery query,
    required String inquiryId,
  }) async {
    final index = _inquiries.indexWhere((i) => i.id == inquiryId);
    if (index < 0) throw StateError('Inquiry not found');
    final leadId = 'lead_$inquiryId';
    final existing = _inquiries[index];
    _inquiries[index] = GrowthInquiry(
      id: existing.id,
      parentName: existing.parentName,
      source: existing.source,
      status: 'converted',
      phone: existing.phone,
      gradeInterest: existing.gradeInterest,
      campaignId: existing.campaignId,
      leadId: leadId,
    );
    return leadId;
  }

  @override
  Future<List<OperationsActionItem>> getOperationsActions({
    required RepositoryQuery query,
  }) async {
    return const [
      OperationsActionItem(
        id: 'action_1',
        module: 'intelligence',
        title: 'Review 3 high-risk students',
        severity: 'high',
        actionType: 'review',
      ),
      OperationsActionItem(
        id: 'action_2',
        module: 'finance',
        title: 'Follow up on 5 overdue fee accounts',
        severity: 'medium',
        actionType: 'follow_up',
      ),
    ];
  }
}
