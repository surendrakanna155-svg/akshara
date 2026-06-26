import 'package:flutter/material.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/operational_action_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../theme/theme_extensions.dart';
import 'intelligence_models.dart';
import 'intelligence_provider.dart';
import '../../theme/spacing.dart';

class IntelligenceScreen extends ConsumerStatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  ConsumerState<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends ConsumerState<IntelligenceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _studentNameController = TextEditingController(text: 'Arjun Reddy');
  final _classController = TextEditingController(text: 'Grade 8');
  final _customNoteController = TextEditingController();
  final _studentIdController = TextEditingController(text: 'student_1');
  final _attendanceController = TextEditingController(text: '62');
  final _marksController = TextEditingController(text: '54');
  final _homeworkController = TextEditingController(text: '55');
  final _yearLabelController = TextEditingController(text: '2025-26');
  final _feeAmountController = TextEditingController(text: '12500');
  final _dueDateController = TextEditingController(text: '15 Jun 2026');
  final _examNameController = TextEditingController(text: 'Term 1 Mathematics');
  final _meetingDateController = TextEditingController(text: '20 Jun 2026');
  final _principalQueryController = TextEditingController(
    text: 'Show students below 75% attendance',
  );

  CommunicationScenario _scenario = CommunicationScenario.lowAttendance;
  GuidanceMode _guidanceMode = GuidanceMode.weekly;
  IntelLanguage _language = IntelLanguage.english;
  IntelLanguage? _parentPreferredLanguage = IntelLanguage.telugu;
  String _principalPeriod = 'monthly';
  bool _publishGuidance = true;
  PrincipalQueryResult? _lastPrincipalQuery;

  List<CommunicationDraft> _lastDrafts = const [];
  ParentGuidanceReport? _lastGuidance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _studentNameController.dispose();
    _classController.dispose();
    _customNoteController.dispose();
    _studentIdController.dispose();
    _attendanceController.dispose();
    _marksController.dispose();
    _homeworkController.dispose();
    _yearLabelController.dispose();
    _feeAmountController.dispose();
    _dueDateController.dispose();
    _examNameController.dispose();
    _meetingDateController.dispose();
    _principalQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = ref.watch(intelligenceCanGenerateProvider);
    final canViewPrincipal = ref.watch(intelligenceCanViewPrincipalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akshara Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Student Risk'),
            Tab(text: 'Communication'),
            Tab(text: 'Parent Guidance'),
            Tab(text: 'Teacher Success'),
            Tab(text: 'Principal Center'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _studentRiskTab(canGenerate),
          _communicationTab(canGenerate),
          _parentGuidanceTab(canGenerate),
          _teacherSuccessTab(),
          _principalTab(canViewPrincipal),
        ],
      ),
    );
  }

  Widget _studentRiskTab(bool canGenerate) {
    final risks = ref.watch(studentRisksListProvider);
    final classes = ref.watch(classRisksListProvider);

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (canGenerate) ...[
          Text('Compute risk snapshots', style: context.aksharaText.titleMedium),
          const SizedBox(height: 8),
          _textField(_yearLabelController, 'Academic year'),
          FilledButton(
            onPressed: () async {
              final count = await ref.read(intelligenceMutationsProvider.notifier).computeRisks(
                    academicYearLabel: _yearLabelController.text.trim(),
                  );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Computed risk for $count students')),
              );
            },
            child: const Text('Compute student risks'),
          ),
          const SizedBox(height: 24),
        ],
        Text('Class risk dashboard', style: context.aksharaText.titleMedium),
        const SizedBox(height: 8),
        classes.when(
          data: (items) => items.isEmpty
              ? const Text('No class summaries yet. Compute risks to populate.')
              : Column(
                  children: items.map(_classRiskCard).toList(),
                ),
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading class risks'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(classRisksListProvider),
          ),
        ),
        const SizedBox(height: 24),
        Text('Student risk dashboard', style: context.aksharaText.titleMedium),
        const SizedBox(height: 8),
        risks.when(
          data: (items) => items.isEmpty
              ? const Text('No student risk snapshots yet.')
              : Column(children: items.map(_studentRiskCard).toList()),
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading student risks'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () => ref.invalidate(studentRisksListProvider),
          ),
        ),
      ],
    );
  }

  Widget _communicationTab(bool canGenerate) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (canGenerate) ...[
          Text('AI Communication Assistant', style: context.aksharaText.titleMedium),
          const SizedBox(height: 8),
          _dropdown('Scenario', _scenario, CommunicationScenario.values, (v) {
            setState(() => _scenario = v);
          }),
          _textField(_studentNameController, 'Student name'),
          _textField(_classController, 'Class'),
          _textField(_customNoteController, 'Custom note (optional)', maxLines: 3),
          _dropdown('Language', _language, IntelLanguage.values, (v) {
            setState(() => _language = v);
          }),
          _dropdown(
            'Parent preferred language (auto-select)',
            _parentPreferredLanguage ?? IntelLanguage.english,
            IntelLanguage.values,
            (v) => setState(() => _parentPreferredLanguage = v),
          ),
          if (_scenario == CommunicationScenario.feeReminder) ...[
            _textField(_feeAmountController, 'Fee amount (₹)'),
            _textField(_dueDateController, 'Due date'),
          ],
          if (_scenario == CommunicationScenario.examReminder)
            _textField(_examNameController, 'Exam name'),
          if (_scenario == CommunicationScenario.parentMeeting)
            _textField(_meetingDateController, 'Meeting date'),
          FilledButton(
            onPressed: () async {
              final drafts = await ref
                  .read(intelligenceMutationsProvider.notifier)
                  .generateCommunication(
                    scenario: _scenario,
                    studentName: _studentNameController.text.trim(),
                    className: _classController.text.trim(),
                    customNote: _customNoteController.text.trim().isEmpty
                        ? null
                        : _customNoteController.text.trim(),
                    languages: [_language],
                    parentPreferredLanguage: _parentPreferredLanguage,
                    feeAmount: _scenario == CommunicationScenario.feeReminder
                        ? _feeAmountController.text.trim()
                        : null,
                    dueDate: _scenario == CommunicationScenario.feeReminder
                        ? _dueDateController.text.trim()
                        : null,
                    examName: _scenario == CommunicationScenario.examReminder
                        ? _examNameController.text.trim()
                        : null,
                    meetingDate: _scenario == CommunicationScenario.parentMeeting
                        ? _meetingDateController.text.trim()
                        : null,
                  );
              setState(() => _lastDrafts = drafts);
            },
            child: const Text('Generate drafts'),
          ),
          const SizedBox(height: 16),
        ] else
          const Text('Generate permission required for communication drafts.'),
        if (_lastDrafts.isNotEmpty) ...[
          Text('Generated drafts', style: context.aksharaText.titleMedium),
          const SizedBox(height: 8),
          ..._lastDrafts.map(_communicationDraftCard),
        ],
      ],
    );
  }

  Widget _parentGuidanceTab(bool canGenerate) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        if (canGenerate) ...[
          Text('Parent Guidance Assistant', style: context.aksharaText.titleMedium),
          const SizedBox(height: 8),
          _textField(_studentIdController, 'Student ID'),
          _dropdown('Mode', _guidanceMode, GuidanceMode.values, (v) {
            setState(() => _guidanceMode = v);
          }),
          _dropdown('Language', _language, IntelLanguage.values, (v) {
            setState(() => _language = v);
          }),
          _textField(_attendanceController, 'Attendance %', keyboardType: TextInputType.number),
          _textField(_marksController, 'Average marks', keyboardType: TextInputType.number),
          _textField(_homeworkController, 'Homework completion %', keyboardType: TextInputType.number),
          SwitchListTile(
            title: const Text('Publish to parent hub'),
            subtitle: const Text('Published reports appear in Parent Experience'),
            value: _publishGuidance,
            onChanged: (v) => setState(() => _publishGuidance = v),
          ),
          FilledButton(
            onPressed: () async {
              final report = await ref
                  .read(intelligenceMutationsProvider.notifier)
                  .generateParentGuidance(
                    studentId: _studentIdController.text.trim(),
                    mode: _guidanceMode,
                    language: _language,
                    publish: _publishGuidance,
                    autoFillFromRisk: true,
                    inputs: {
                      if (_attendanceController.text.isNotEmpty)
                        'attendancePercent': int.tryParse(_attendanceController.text),
                      if (_marksController.text.isNotEmpty)
                        'averageMarks': int.tryParse(_marksController.text),
                      if (_homeworkController.text.isNotEmpty)
                        'homeworkCompletionRate': int.tryParse(_homeworkController.text),
                      'studentName': _studentNameController.text.trim(),
                    },
                  );
              setState(() => _lastGuidance = report);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    report.status == 'published'
                        ? 'Guidance published — visible in parent hub'
                        : 'Guidance saved as draft',
                  ),
                ),
              );
            },
            child: const Text('Generate & publish guidance'),
          ),
          const SizedBox(height: 16),
        ] else
          const Text('Generate permission required for parent guidance.'),
        if (_lastGuidance != null) _guidanceReportCard(_lastGuidance!),
      ],
    );
  }

  Widget _teacherSuccessTab() {
    final center = ref.watch(teacherSuccessCenterProvider);
    return center.when(
      data: (data) => ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          _metricRow('Risk students', data.riskStudents),
          _metricRow('Homework gaps', data.homeworkGaps),
          _metricRow('Attendance concerns', data.attendanceConcerns),
          _metricRow('Pending parent communication', data.pendingParentCommunication),
          const SizedBox(height: 16),
          Text('Daily action planner', style: context.aksharaText.titleMedium),
          if (data.dailyActionPlan.isEmpty)
            const ListTile(title: Text('No actions planned — review risk dashboard'))
          else
            ...data.dailyActionPlan.map(
              (a) => ListTile(
                leading: Icon(
                  a.priority == 'high'
                      ? Icons.priority_high
                      : a.priority == 'medium'
                          ? Icons.schedule
                          : Icons.check_circle_outline,
                ),
                title: Text(a.action),
                subtitle: Text('${a.category} · ${a.priority} priority'),
              ),
            ),
          const SizedBox(height: 16),
          Text('Students needing attention', style: context.aksharaText.titleMedium),
          ...data.studentsNeedingAttention.map(
            (s) => ListTile(
              title: Text(s['studentName']?.toString() ?? 'Student'),
              subtitle: Text(
                '${s['className']} · ${s['riskLevel']} (${s['riskScore']}) — ${s['topReason']}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Insights', style: context.aksharaText.titleMedium),
          _chipSection('Weak students', data.weakStudents),
          _chipSection('Improving students', data.improvingStudents),
          _chipSection('High performers', data.highPerformers),
          const SizedBox(height: 16),
          Text('Suggested actions', style: context.aksharaText.titleMedium),
          ...data.suggestedActions.map(
            (a) => ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(a['action']?.toString() ?? ''),
              subtitle: Text('${a['type']} → ${a['target']}'),
            ),
          ),
        ],
      ),
      loading: () => const AksharaLoadingState(semanticLabel: 'Loading teacher center'),
      error: (e, _) => AksharaErrorState.fromFailure(
        apiFailureMapper.fromException(e),
        onRetry: () => ref.invalidate(teacherSuccessCenterProvider),
      ),
    );
  }

  Widget _principalTab(bool canView) {
    if (!canView) {
      return const Center(child: Text('Analytics permission required for Principal Center.'));
    }
    final center = ref.watch(principalIntelligenceProvider(_principalPeriod));
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ButtonSegment(value: 'quarterly', label: Text('Quarterly')),
          ],
          selected: {_principalPeriod},
          onSelectionChanged: (value) {
            setState(() => _principalPeriod = value.first);
          },
        ),
        const SizedBox(height: 16),
        Text('Natural language query', style: context.aksharaText.titleMedium),
        _textField(_principalQueryController, 'Ask about students, fees, attendance'),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Low attendance'),
              onPressed: () => _principalQueryController.text =
                  'Show students below 75% attendance',
            ),
            ActionChip(
              label: const Text('High risk'),
              onPressed: () =>
                  _principalQueryController.text = 'Show high-risk students',
            ),
            ActionChip(
              label: const Text('Fee defaulters'),
              onPressed: () =>
                  _principalQueryController.text = 'Show fee defaulters',
            ),
          ],
        ),
        FilledButton(
          onPressed: () async {
            final result = await ref.read(intelligenceRepositoryProvider).queryPrincipal(
                  query: ref.read(intelligenceQueryProvider),
                  queryText: _principalQueryController.text.trim(),
                );
            setState(() => _lastPrincipalQuery = result);
          },
          child: const Text('Run query'),
        ),
        if (_lastPrincipalQuery != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_lastPrincipalQuery!.summary,
                      style: context.aksharaText.titleSmall),
                  const SizedBox(height: 8),
                  ..._lastPrincipalQuery!.items.take(10).map(
                        (item) => ListTile(
                          dense: true,
                          title: Text(item['studentName']?.toString() ?? 'Student'),
                          subtitle: Text(item.toString()),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        center.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metricRow('School health score', data.schoolHealthScore),
              _metricRow('Students at risk', data.studentsAtRisk),
              _metricRow('Critical risk count', data.criticalRiskCount),
              if (data.executiveDashboard != null) ...[
                _metricRow('Overloaded teachers', data.executiveDashboard!.overloadedTeachers),
                ListTile(
                  title: const Text('Attendance trend'),
                  trailing: Text(data.executiveDashboard!.attendanceTrend),
                ),
                ListTile(
                  title: const Text('Fee collection'),
                  trailing: Text(data.executiveDashboard!.feeCollectionTrend),
                ),
                ListTile(
                  title: const Text('Communication'),
                  trailing: Text(data.executiveDashboard!.communicationEffectiveness),
                ),
                ListTile(
                  title: const Text('Class performance'),
                  trailing: Text(data.executiveDashboard!.classPerformanceTrend),
                ),
              ],
              const SizedBox(height: 16),
              Text('School health insights', style: context.aksharaText.titleMedium),
              ...data.insights.map((i) => ListTile(title: Text(i))),
              const SizedBox(height: 16),
              Text('Intervention recommendations',
                  style: context.aksharaText.titleMedium),
              ...data.interventions.map((i) => ListTile(title: Text(i))),
              const SizedBox(height: 16),
              Text('Class risk summaries', style: context.aksharaText.titleMedium),
              ...data.classSummaries.map(_classRiskCard),
              const SizedBox(height: 16),
              Text('Export summaries', style: context.aksharaText.titleMedium),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Text(
                    _principalPeriod == 'quarterly'
                        ? data.quarterlySummary
                        : data.monthlySummary,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const AksharaLoadingState(semanticLabel: 'Loading principal center'),
          error: (e, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(e),
            onRetry: () =>
                ref.invalidate(principalIntelligenceProvider(_principalPeriod)),
          ),
        ),
      ],
    );
  }

  Widget _studentRiskCard(StudentRiskSnapshot risk) {
    return Card(
      child: ExpansionTile(
        title: Text('${risk.studentName ?? risk.studentId} — ${risk.riskLevel.name}'),
        subtitle: Text('${risk.className} · Score ${risk.riskScore}'),
        children: [
          if (risk.reasons.isNotEmpty) ...[
            const ListTile(title: Text('Risk reasons', style: TextStyle(fontWeight: FontWeight.bold))),
            ...risk.reasons.map(
              (r) => ListTile(
                dense: true,
                title: Text(r['label']?.toString() ?? ''),
                subtitle: Text(r['detail']?.toString() ?? ''),
              ),
            ),
          ],
          if (risk.interventions.isNotEmpty) ...[
            const ListTile(
                title: Text('Interventions', style: TextStyle(fontWeight: FontWeight.bold))),
            ...risk.interventions.map(
              (i) => ListTile(
                dense: true,
                title: Text(i['action']?.toString() ?? ''),
                subtitle: Text('${i['owner']} · ${i['priority']}'),
              ),
            ),
          ],
          if (risk.teacherActions.isNotEmpty)
            ListTile(
              title: const Text('Teacher actions'),
              subtitle: Text(risk.teacherActions.join('\n')),
            ),
          if (risk.parentNotifications.isNotEmpty)
            ListTile(
              title: const Text('Parent notification recommendations'),
              subtitle: Text(risk.parentNotifications.join('\n')),
            ),
        ],
      ),
    );
  }

  Widget _classRiskCard(ClassRiskSummary summary) {
    return Card(
      child: ListTile(
        title: Text(summary.className),
        subtitle: Text(
          '${summary.studentCount} students · avg score ${summary.averageRiskScore}',
        ),
        trailing: Text(
          'C${summary.criticalCount} H${summary.highCount} M${summary.mediumCount} L${summary.lowCount}',
        ),
      ),
    );
  }

  Widget _communicationDraftCard(CommunicationDraft draft) {
    return Card(
      child: ExpansionTile(
        title: Text('${draft.language.name} draft'),
        children: [
          ListTile(title: const Text('Professional'), subtitle: Text(draft.professional)),
          ListTile(title: const Text('Parent-friendly'), subtitle: Text(draft.parentFriendly)),
          ListTile(title: const Text('WhatsApp'), subtitle: Text(draft.channels.whatsapp)),
          ListTile(title: const Text('SMS'), subtitle: Text(draft.channels.sms)),
          ListTile(title: const Text('Email'), subtitle: Text(draft.channels.email)),
        ],
      ),
    );
  }

  Widget _guidanceReportCard(ParentGuidanceReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Progress summary',
                      style: context.aksharaText.titleMedium),
                ),
                if (report.printable)
                  TextButton.icon(
                    onPressed: () => showAksharaReportExportPreviewSnackBar(
                      context,
                      reportName: 'Parent guidance report',
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print'),
                  ),
                Chip(
                  label: Text(report.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(report.progressSummary),
            const SizedBox(height: 12),
            _chipSection('Strengths', report.strengths),
            _chipSection('Concerns', report.concerns),
            _chipSection('Study recommendations', report.studyRecommendations),
            _chipSection('Next steps', report.nextStepGuidance),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, int value) {
    return ListTile(
      title: Text(label),
      trailing: Text('$value', style: context.aksharaText.titleLarge),
    );
  }

  Widget _chipSection(String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: items.map((i) => Chip(label: Text(i))).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> options,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            items: options
                .map(
                  (o) => DropdownMenuItem<T>(
                    value: o,
                    child: Text((o as dynamic).name),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
