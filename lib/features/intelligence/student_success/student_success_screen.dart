import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../features/copilot/copilot_context_provider.dart';
import '../../../features/copilot/copilot_screen_context.dart';
import '../../../router/route_names.dart';
import '../../../router/student360_navigation.dart';
import '../intelligence_provider.dart';
import 'attendance_intelligence.dart';
import 'attendance_intelligence_provider.dart';
import 'at_risk_student_intelligence.dart';
import 'at_risk_student_provider.dart';
import '../academic/promotion_readiness_intelligence.dart';
import '../academic/promotion_readiness_provider.dart';
import 'student_success_models.dart';
import 'student_success_provider.dart';

class StudentSuccessScreen extends ConsumerStatefulWidget {
  const StudentSuccessScreen({super.key});

  @override
  ConsumerState<StudentSuccessScreen> createState() => _StudentSuccessScreenState();
}

class _StudentSuccessScreenState extends ConsumerState<StudentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canView = ref.watch(studentSuccessCanViewProvider);
    if (!canView) {
      return const Scaffold(
        body: Center(child: Text('Student Success Intelligence permission required.')),
      );
    }

    final canGenerate = ref.watch(intelligenceCanGenerateProvider);
    final dashboard = ref.watch(studentSuccessDashboardProvider);
    final predictions = ref.watch(studentSuccessPredictionsProvider);
    final improvements = ref.watch(studentImprovementsProvider);
    final interventions = ref.watch(interventionEffectivenessProvider);

    final atRisk = ref.watch(atRiskStudentProfilesProvider);
    final attendance = ref.watch(attendanceIntelligenceProfilesProvider);
    final promotion = ref.watch(promotionReviewQueueProvider);

    return dashboard.when(
      data: (dashboardData) {
        final profiles = atRisk.valueOrNull ?? const <AtRiskStudentProfile>[];
        final atRiskSummary = profiles.isEmpty ? null : summarizeAtRiskProfiles(profiles);
        final criticalCount = atRiskSummary?.criticalCount ?? dashboardData.highDropoutRiskCount;
        return CopilotContextScope(
          route: RouteNames.studentSuccessIntelligence,
          module: 'intelligence',
          screen: 'Student Success Intelligence',
          kpis: [
            CopilotKpiSnapshot(
              id: 'students_analyzed',
              label: 'Students analyzed',
              value: '${dashboardData.studentsAnalyzed}',
            ),
            CopilotKpiSnapshot(
              id: 'at_risk',
              label: 'At-risk flagged',
              value: '${atRiskSummary?.totalFlagged ?? dashboardData.highDropoutRiskCount}',
            ),
            CopilotKpiSnapshot(
              id: 'critical_risk',
              label: 'Critical risk',
              value: '$criticalCount',
            ),
          ],
          child: _buildScaffold(
            canGenerate: canGenerate,
            dashboard: dashboardData,
            predictions: predictions,
            improvements: improvements,
            interventions: interventions,
            atRisk: atRisk,
            attendance: attendance,
            promotion: promotion,
          ),
        );
      },
      loading: () => _buildScaffold(
        canGenerate: canGenerate,
        dashboard: null,
        predictions: predictions,
        improvements: improvements,
        interventions: interventions,
        atRisk: atRisk,
        attendance: attendance,
        promotion: promotion,
      ),
      error: (e, _) => _buildScaffold(
        canGenerate: canGenerate,
        dashboard: null,
        dashboardError: '$e',
        predictions: predictions,
        improvements: improvements,
        interventions: interventions,
        atRisk: atRisk,
        attendance: attendance,
        promotion: promotion,
      ),
    );
  }

  Widget _buildScaffold({
    required bool canGenerate,
    required AsyncValue<List<StudentSuccessSnapshot>> predictions,
    required AsyncValue<List<StudentImprovementItem>> improvements,
    required AsyncValue<List<InterventionEffectivenessItem>> interventions,
    required AsyncValue<List<AtRiskStudentProfile>> atRisk,
    required AsyncValue<List<AttendanceIntelligenceProfile>> attendance,
    required AsyncValue<List<PromotionReadinessProfile>> promotion,
    StudentSuccessDashboard? dashboard,
    String? dashboardError,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Success Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'At-Risk'),
            Tab(text: 'Attendance'),
            Tab(text: 'Promotion'),
            Tab(text: 'Predictions'),
            Tab(text: 'Improvements'),
            Tab(text: 'Interventions'),
          ],
        ),
        actions: [
          if (canGenerate)
            IconButton(
              tooltip: 'Compute predictions',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final count = await ref.read(studentSuccessMutationsProvider.notifier).compute();
                messenger.showSnackBar(
                  SnackBar(content: Text('Computed success intelligence for $count students')),
                );
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          if (dashboard != null)
            _dashboardTab(dashboard)
          else if (dashboardError != null)
            Center(child: Text('Error: $dashboardError'))
          else
            const Center(child: CircularProgressIndicator()),
          atRisk.when(
            data: (profiles) => _atRiskTab(profiles),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          attendance.when(
            data: (profiles) => _attendanceTab(profiles),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          promotion.when(
            data: (profiles) => _promotionTab(profiles),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          predictions.when(
            data: (items) => _predictionsTab(items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          improvements.when(
            data: (items) => _improvementsTab(items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          interventions.when(
            data: (items) => _interventionsTab(items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTab(List<AttendanceIntelligenceProfile> profiles) {
    if (profiles.isEmpty) {
      return const Center(child: Text('No attendance risks flagged at watch tier or above.'));
    }

    final summary = summarizeAttendanceProfiles(profiles);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metricTile('Flagged students', summary.totalFlagged),
        _metricTile('Chronic risk', summary.chronicCount),
        _metricTile('At risk', summary.atRiskCount),
        _metricTile('Watch list', summary.watchCount),
        _metricTile('Avg predicted attendance', summary.averagePrediction),
        const SizedBox(height: 16),
        Text('Attendance intervention queue', style: Theme.of(context).textTheme.titleMedium),
        for (final profile in summary.topProfiles)
          ListTile(
            title: Text('${profile.studentName} · ${profile.tier.label}'),
            subtitle: Text(
              '${profile.className} · ${profile.primarySignal}\n${profile.recommendedAction}',
            ),
            isThreeLine: true,
          ),
      ],
    );
  }

  Widget _promotionTab(List<PromotionReadinessProfile> profiles) {
    if (profiles.isEmpty) {
      return const Center(child: Text('No students require promotion review.'));
    }

    final allProfiles = ref.read(promotionReadinessProfilesProvider).valueOrNull ?? profiles;
    final summary = summarizePromotionReadiness(allProfiles);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metricTile('Students assessed', summary.totalAssessed),
        _metricTile('Ready', summary.readyCount),
        _metricTile('Borderline', summary.borderlineCount),
        _metricTile('Not ready', summary.notReadyCount),
        _metricTile('Hold', summary.holdCount),
        const SizedBox(height: 16),
        Text('Promotion review queue', style: Theme.of(context).textTheme.titleMedium),
        for (final profile in profiles)
          ListTile(
            title: Text('${profile.studentName} · ${profile.readiness.label}'),
            subtitle: Text(
              '${profile.className} · Score ${profile.readinessScore}\n${profile.recommendedAction}',
            ),
            isThreeLine: true,
          ),
      ],
    );
  }

  Widget _atRiskTab(List<AtRiskStudentProfile> profiles) {
    if (profiles.isEmpty) {
      return const Center(child: Text('No at-risk students flagged at medium tier or above.'));
    }

    final summary = summarizeAtRiskProfiles(profiles);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metricTile('Flagged students', summary.totalFlagged),
        _metricTile('Critical', summary.criticalCount),
        _metricTile('High', summary.highCount),
        _metricTile('Medium', summary.mediumCount),
        const SizedBox(height: 16),
        Text('Intervention queue', style: Theme.of(context).textTheme.titleMedium),
        for (final profile in summary.topProfiles)
          ListTile(
            key: QaTestKeys.atRiskStudentRow(profile.studentId),
            title: Text('${profile.studentName} · ${profile.tier.label}'),
            subtitle: Text(
              '${profile.className} · ${profile.primarySignal}\n${profile.recommendedAction}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.hub_outlined),
            onTap: () => openStudent360(context, profile.studentId),
          ),
      ],
    );
  }

  Widget _dashboardTab(StudentSuccessDashboard d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metricTile('Students analyzed', d.studentsAnalyzed),
        _metricTile('High dropout risk', d.highDropoutRiskCount),
        _metricTile('Attendance risk', d.attendanceRiskCount),
        _metricTile('Performance decline', d.performanceDeclineCount),
        _metricTile('Improving students', d.improvingStudentsCount),
        _metricTile('Avg improvement score', d.averageImprovementScore),
        const SizedBox(height: 16),
        Text('Insights', style: Theme.of(context).textTheme.titleMedium),
        ...d.insights.map((i) => ListTile(title: Text(i))),
        const SizedBox(height: 16),
        Text('Top risk students', style: Theme.of(context).textTheme.titleMedium),
        ...d.topRiskStudents.map(
          (s) => ListTile(
            title: Text(s['studentName']?.toString() ?? 'Student'),
            subtitle: Text(
              '${s['className']} · Dropout ${s['dropoutProbability']}% — ${s['topSignal']}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _predictionsTab(List<StudentSuccessSnapshot> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No predictions yet. Run compute to populate.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map(_predictionCard).toList(),
    );
  }

  Widget _predictionCard(StudentSuccessSnapshot s) {
    return Card(
      child: ExpansionTile(
        title: Text('${s.studentName} — ${s.dropoutProbability}% dropout risk'),
        subtitle: Text(
          '${s.className} · Attendance pred ${s.attendancePrediction}% · Decline ${s.performanceDeclineScore}',
        ),
        children: [
          ListTile(
            title: const Text('Dropout outlook'),
            subtitle: Text(s.predictions['dropoutRisk']?.toString() ?? ''),
          ),
          ListTile(
            title: const Text('Attendance outlook'),
            subtitle: Text(s.predictions['attendanceOutlook']?.toString() ?? ''),
          ),
          ListTile(
            title: const Text('Performance trend'),
            subtitle: Text(s.predictions['performanceTrend']?.toString() ?? ''),
          ),
          if (s.riskSignals.isNotEmpty) ...[
            const ListTile(title: Text('Risk signals', style: TextStyle(fontWeight: FontWeight.bold))),
            ...s.riskSignals.map(
              (r) => ListTile(
                dense: true,
                title: Text(r['label']?.toString() ?? ''),
                trailing: Text(r['severity']?.toString() ?? ''),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _improvementsTab(List<StudentImprovementItem> items) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items
          .map(
            (i) => Card(
              child: ListTile(
                title: Text('${i.studentName} (${i.trend})'),
                subtitle: Text(
                  '${i.className} · Score ${i.improvementScore}\n${i.highlights.join(' · ')}',
                ),
                isThreeLine: true,
                trailing: Icon(
                  i.trend == 'improving'
                      ? Icons.trending_up
                      : i.trend == 'declining'
                          ? Icons.trending_down
                          : Icons.trending_flat,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _interventionsTab(List<InterventionEffectivenessItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No intervention records yet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items
          .map(
            (i) => ListTile(
              title: Text(i.interventionLabel),
              subtitle: Text(
                '${i.interventionType} · ${i.status}'
                '${i.effectivenessScore != null ? ' · Effectiveness ${i.effectivenessScore}%' : ''}'
                '${i.outcome != null ? '\n${i.outcome}' : ''}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }

  Widget _metricTile(String label, int value) {
    return ListTile(
      title: Text(label),
      trailing: Text('$value', style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
