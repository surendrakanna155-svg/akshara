import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_intelligence_models.dart';
import 'exam_intelligence_provider.dart';

class ExamIntelligenceScreen extends ConsumerStatefulWidget {
  const ExamIntelligenceScreen({super.key});

  @override
  ConsumerState<ExamIntelligenceScreen> createState() => _ExamIntelligenceScreenState();
}

class _ExamIntelligenceScreenState extends ConsumerState<ExamIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _classController = TextEditingController(text: 'Grade 8');
  final _subjectController = TextEditingController(text: 'Mathematics');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _classController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  ExamIntelFilters get _filters => (
        className: _classController.text.trim().isEmpty ? null : _classController.text.trim(),
        subjectName:
            _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
      );

  void _refresh() {
    ref.invalidate(examAnalyticsProvider(_filters));
    ref.invalidate(subjectPerformanceProvider(_filters));
    ref.invalidate(weakChaptersProvider(_filters));
    ref.invalidate(resultIntelligenceProvider(_filters.className));
    ref.invalidate(academicForecastProvider(_filters));
    ref.invalidate(rankMovementProvider(_filters.className));
  }

  @override
  Widget build(BuildContext context) {
    final canView = ref.watch(examIntelligenceCanViewProvider);
    if (!canView) {
      return const Scaffold(
        body: Center(child: Text('Exam Intelligence permission required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam & Academic Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Analytics'),
            Tab(text: 'Subjects'),
            Tab(text: 'Weak Chapters'),
            Tab(text: 'Results'),
            Tab(text: 'Forecast'),
            Tab(text: 'Rank Movement'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _classController,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _refresh, child: const Text('Apply')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _analyticsTab(),
                _subjectsTab(),
                _weakChaptersTab(),
                _resultsTab(),
                _forecastTab(),
                _rankTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsTab() {
    final data = ref.watch(examAnalyticsProvider(_filters));
    return data.when(
      data: (a) => _analyticsContent(a),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _analyticsContent(ExamAnalytics a) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metric('Total exams', a.totalExams),
        _metric('Students assessed', a.studentsAssessed),
        _metric('Average score', a.averageScorePercent),
        _metric('Pass rate', a.passRatePercent),
        const SizedBox(height: 12),
        Text('Insights', style: Theme.of(context).textTheme.titleMedium),
        ...a.insights.map((i) => ListTile(title: Text(i))),
        Text('Top performers', style: Theme.of(context).textTheme.titleMedium),
        ...a.topPerformers.map(
          (p) => ListTile(
            title: Text(p['studentName']?.toString() ?? ''),
            trailing: Text('${p['avgPercent']}%'),
          ),
        ),
      ],
    );
  }

  Widget _subjectsTab() {
    final data = ref.watch(subjectPerformanceProvider(_filters));
    return data.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: items
            .map(
              (s) => ListTile(
                title: Text(s.subjectName),
                subtitle: Text('${s.studentCount} students · ${s.trend}'),
                trailing: Text('${s.avgPercent}%'),
              ),
            )
            .toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _weakChaptersTab() {
    final data = ref.watch(weakChaptersProvider(_filters));
    return data.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: items
            .map(
              (w) => Card(
                child: ListTile(
                  title: Text('${w.chapter} (${w.subjectName})'),
                  subtitle: Text('${w.avgPercent}% avg · ${w.recommendation}'),
                ),
              ),
            )
            .toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _resultsTab() {
    final data = ref.watch(resultIntelligenceProvider(_filters.className));
    return data.when(
      data: (r) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _metric('Pass count', r.passCount),
          _metric('Fail count', r.failCount),
          _metric('Distinctions', r.distinctionCount),
          ...r.insights.map((i) => ListTile(title: Text(i))),
          Text('Grade distribution', style: Theme.of(context).textTheme.titleMedium),
          ...r.gradeDistribution.map(
            (g) => ListTile(
              title: Text('Grade ${g['grade']}'),
              trailing: Text('${g['count']}'),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _forecastTab() {
    final data = ref.watch(academicForecastProvider(_filters));
    return data.when(
      data: (f) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _metric('Predicted avg', f.predictedAvgPercent),
          _metric('At-risk students', f.atRiskStudentCount),
          _metric('Improving students', f.improvingStudentCount),
          Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
          ...f.recommendations.map((r) => ListTile(title: Text(r))),
          Text('Subject forecasts', style: Theme.of(context).textTheme.titleMedium),
          ...f.subjectForecasts.map(
            (s) => ListTile(
              title: Text(s['subjectName']?.toString() ?? ''),
              subtitle: Text('Confidence: ${s['confidence']}'),
              trailing: Text('${s['predictedAvg']}%'),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _rankTab() {
    final data = ref.watch(rankMovementProvider(_filters.className));
    return data.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: items
            .map(
              (r) => ListTile(
                title: Text(r.studentName),
                subtitle: Text('${r.className} · ${r.previousRank} → ${r.currentRank}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      r.direction == 'up'
                          ? Icons.arrow_upward
                          : r.direction == 'down'
                              ? Icons.arrow_downward
                              : Icons.remove,
                      size: 18,
                    ),
                    Text(' ${r.movement}'),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _metric(String label, int value) {
    return ListTile(
      title: Text(label),
      trailing: Text('$value', style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
