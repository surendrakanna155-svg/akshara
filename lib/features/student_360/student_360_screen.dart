import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import '../phase4/phase4_providers.dart';
import 'student_360_models.dart';

class Student360Screen extends ConsumerWidget {
  const Student360Screen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(student360ProfileProvider(studentId));
    final timeline = ref.watch(student360TimelineProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Student 360')),
      body: profile.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _identityHeader(context, data),
            const SizedBox(height: 16),
            _metricCard(
              context,
              'Attendance',
              Icons.event_available_outlined,
              _attendanceMetrics(data.attendance),
            ),
            _metricCard(
              context,
              'Academic performance',
              Icons.school_outlined,
              _marksMetrics(data.marks),
            ),
            _metricCard(
              context,
              'Homework',
              Icons.assignment_outlined,
              _homeworkMetrics(data.homework),
            ),
            _metricCard(
              context,
              'Risk profile',
              Icons.warning_amber_outlined,
              _riskMetrics(data.risk),
            ),
            _metricCard(
              context,
              'Fees',
              Icons.payments_outlined,
              _feesMetrics(data.fees),
            ),
            _metricCard(
              context,
              'Inventory',
              Icons.inventory_2_outlined,
              _inventoryMetrics(data.inventory),
            ),
            const SizedBox(height: 8),
            Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            timeline.when(
              data: (events) => events.isEmpty
                  ? const AksharaEmptyState(
                      message: 'No timeline events yet. Activity will appear as the student engages with school modules.',
                    )
                  : Column(
                      children: events.map(_timelineTile).toList(),
                    ),
              loading: () => const AksharaLoadingState(semanticLabel: 'Loading timeline'),
              error: (e, _) => AksharaErrorState(
                message: 'Unable to load timeline.',
                onRetry: () => ref.invalidate(student360TimelineProvider(studentId)),
              ),
            ),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading student profile'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load student profile.',
          onRetry: () => ref.invalidate(student360ProfileProvider(studentId)),
        ),
      ),
    );
  }

  Widget _identityHeader(BuildContext context, Student360Profile data) {
    final name = data.identity['name']?.toString() ?? studentId;
    final className = data.identity['className']?.toString() ?? '';
    final section = data.identity['sectionName']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            if (className.isNotEmpty)
              Text(
                section != null ? '$className · $section' : className,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (data.parentInformation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Parent: ${data.parentInformation['guardianName'] ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    IconData icon,
    List<_MetricRow> metrics,
  ) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(metrics.first.label),
        children: metrics
            .map(
              (m) => ListTile(
                dense: true,
                title: Text(m.label),
                trailing: Text(
                  m.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<_MetricRow> _attendanceMetrics(Map<String, dynamic> data) {
    final pct = data['percent'] ?? data['attendancePercent'];
    if (pct == null) return [];
    return [
      _MetricRow('Attendance rate', '$pct%'),
      if (data['presentDays'] != null)
        _MetricRow('Present days', '${data['presentDays']}'),
      if (data['absentDays'] != null) _MetricRow('Absent days', '${data['absentDays']}'),
    ];
  }

  List<_MetricRow> _marksMetrics(Map<String, dynamic> data) {
    final avg = data['average'] ?? data['averageMarks'];
    if (avg == null && data.isEmpty) return [];
    return [
      if (avg != null) _MetricRow('Average marks', '$avg%'),
      if (data['subjectsAssessed'] != null)
        _MetricRow('Subjects assessed', '${data['subjectsAssessed']}'),
      if (data['trend'] != null) _MetricRow('Trend', '${data['trend']}'),
    ];
  }

  List<_MetricRow> _homeworkMetrics(Map<String, dynamic> data) {
    final rate = data['completionRate'] ?? data['homeworkCompletionRate'];
    if (rate == null && data.isEmpty) return [];
    return [
      if (rate != null) _MetricRow('Completion rate', '$rate%'),
      if (data['pendingCount'] != null)
        _MetricRow('Pending assignments', '${data['pendingCount']}'),
    ];
  }

  List<_MetricRow> _riskMetrics(Map<String, dynamic> data) {
    if (data.isEmpty) return [];
    return [
      if (data['riskLevel'] != null) _MetricRow('Risk level', '${data['riskLevel']}'),
      if (data['riskScore'] != null) _MetricRow('Risk score', '${data['riskScore']}'),
      if (data['topReason'] != null) _MetricRow('Top reason', '${data['topReason']}'),
    ];
  }

  List<_MetricRow> _feesMetrics(Map<String, dynamic> data) {
    if (data.isEmpty) return [];
    return [
      if (data['outstanding'] != null) _MetricRow('Outstanding', '₹${data['outstanding']}'),
      if (data['paidPercent'] != null) _MetricRow('Paid', '${data['paidPercent']}%'),
    ];
  }

  List<_MetricRow> _inventoryMetrics(Map<String, dynamic> data) {
    if (data.isEmpty) return [];
    return [
      if (data['itemsIssued'] != null) _MetricRow('Items issued', '${data['itemsIssued']}'),
      if (data['pendingAck'] != null)
        _MetricRow('Pending acknowledgement', '${data['pendingAck']}'),
    ];
  }

  Widget _timelineTile(StudentTimelineEvent event) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(event.title),
      subtitle: Text('${event.eventType} · ${event.sourceModule}\n${event.eventAt}'),
      isThreeLine: true,
    );
  }
}

class _MetricRow {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;
}
