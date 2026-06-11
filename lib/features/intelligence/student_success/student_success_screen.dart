import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../intelligence_provider.dart';
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
    _tabs = TabController(length: 4, vsync: this);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Success Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
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
          dashboard.when(
            data: (d) => _dashboardTab(d),
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
