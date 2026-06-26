import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reports/akshara_report_export_service.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import '../phase4/phase4_providers.dart';
import 'student_360_models.dart';
import '../../theme/spacing.dart';

class Student360Screen extends ConsumerStatefulWidget {
  const Student360Screen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<Student360Screen> createState() => _Student360ScreenState();
}

class _Student360ScreenState extends ConsumerState<Student360Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(student360ProfileProvider(widget.studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student 360'),
        actions: [
          profile.maybeWhen(
            data: (raw) {
              final data = raw as Student360Profile;
              return IconButton(
                key: QaTestKeys.student360ExportButton,
                tooltip: 'Export dossier',
                onPressed: () async {
                  final service =
                      ref.read(aksharaReportExportServiceProvider);
                  final name = data.identity['name']?.toString() ??
                      data.identity['displayName']?.toString() ??
                      widget.studentId;
                  final bytes = await service.buildTabularReportPdf(
                    reportTitle: 'Student 360 Dossier',
                    moduleLabel: 'SIS · $name',
                    generatedAtLabel: DateTime.now().toIso8601String(),
                    rows: [
                      MapEntry('Student ID', widget.studentId),
                      MapEntry('Name', name),
                      MapEntry(
                        'Class',
                        '${data.identity['className'] ?? ''} ${data.identity['sectionName'] ?? ''}'
                            .trim(),
                      ),
                      MapEntry(
                        'Attendance %',
                        '${data.attendance['percent'] ?? '—'}',
                      ),
                      MapEntry(
                        'Fee paid %',
                        '${data.fees['paidPercent'] ?? '—'}',
                      ),
                      MapEntry(
                        'Risk level',
                        '${data.risk['riskLevel'] ?? '—'}',
                      ),
                    ],
                  );
                  if (!context.mounted) return;
                  await service.previewPdf(
                    documentName: 'student_360_${widget.studentId}.pdf',
                    bytes: bytes,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      key: QaTestKeys.student360ExportSuccessSnackbar,
                      content: Text('Student 360 dossier PDF ready'),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          key: QaTestKeys.student360TabBar,
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
            Tab(text: 'Academics'),
            Tab(text: 'Homework'),
            Tab(text: 'Fees'),
            Tab(text: 'Communication'),
            Tab(text: 'Behaviour'),
            Tab(text: 'Transport'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: profile.when(
        data: (raw) {
          final data = raw as Student360Profile;
          final timelineRaw = ref.watch(student360TimelineProvider(widget.studentId));
          return TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
              studentId: widget.studentId,
              data: data,
              timeline: timelineRaw,
            ),
            _MetricTab(
              title: 'Attendance',
              icon: Icons.event_available_outlined,
              metrics: _attendanceMetrics(data.attendance),
            ),
            _MetricTab(
              title: 'Academic performance',
              icon: Icons.school_outlined,
              metrics: _marksMetrics(data.marks),
            ),
            _MetricTab(
              title: 'Homework',
              icon: Icons.assignment_outlined,
              metrics: _homeworkMetrics(data.homework),
            ),
            _MetricTab(
              title: 'Fees',
              icon: Icons.payments_outlined,
              metrics: _feesMetrics(data.fees),
            ),
            _CommunicationTab(
              communication: data.communication,
              timeline: timelineRaw,
            ),
            _MetricTab(
              title: 'Behaviour',
              icon: Icons.psychology_outlined,
              metrics: _behaviourMetrics(data.behaviour),
            ),
            _MetricTab(
              title: 'Transport',
              icon: Icons.directions_bus_outlined,
              metrics: _transportMetrics(data.transport),
            ),
            _MetricTab(
              title: 'Documents',
              icon: Icons.folder_outlined,
              metrics: _documentsMetrics(data.documents),
            ),
          ],
        );
        },
        loading: () =>
            const AksharaLoadingState(semanticLabel: 'Loading student profile'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load student profile.',
          onRetry: () =>
              ref.invalidate(student360ProfileProvider(widget.studentId)),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.studentId,
    required this.data,
    required this.timeline,
  });

  final String studentId;
  final Student360Profile data;
  final AsyncValue<dynamic> timeline;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        _identityHeader(context, data),
        const SizedBox(height: 16),
        _summaryRow(context, data),
        const SizedBox(height: 16),
        Text('Timeline', style: context.aksharaText.titleMedium),
        const SizedBox(height: 8),
        timeline.when(
          data: (rawEvents) {
            final events = (rawEvents as List).cast<StudentTimelineEvent>();
            return events.isEmpty
              ? const AksharaEmptyState(
                  message:
                      'No timeline events yet. Activity will appear as the student engages with school modules.',
                )
              : Column(children: events.map(_timelineTile).toList());
          },
          loading: () =>
              const AksharaLoadingState(semanticLabel: 'Loading timeline'),
          error: (e, _) => const AksharaEmptyState(
            message: 'Timeline unavailable.',
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _identityHeader(BuildContext context, Student360Profile data) {
    final name = data.identity['name']?.toString() ??
        data.identity['displayName']?.toString() ??
        studentId;
    final className = data.identity['className']?.toString() ?? '';
    final section = data.identity['sectionName']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: context.aksharaText.headlineSmall),
            if (className.isNotEmpty)
              Text(
                section != null ? '$className · $section' : className,
                style: context.aksharaText.bodyMedium,
              ),
            if (data.parentInformation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Parent: ${_guardianLabel(data.parentInformation)}',
                style: context.aksharaText.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, Student360Profile data) {
    final items = [
      _attendanceMetrics(data.attendance).firstOrNull,
      _marksMetrics(data.marks).firstOrNull,
      _homeworkMetrics(data.homework).firstOrNull,
      _feesMetrics(data.fees).firstOrNull,
      _riskMetrics(data.risk).firstOrNull,
    ].whereType<_MetricRow>().toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Chip(
            avatar: const Icon(Icons.insights_outlined, size: 18),
            label: Text('${item.label}: ${item.value}'),
          ),
      ],
    );
  }

  Widget _timelineTile(StudentTimelineEvent event) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(event.title),
      subtitle: Text(
        '${event.eventType} · ${event.sourceModule}\n${event.eventAt}',
      ),
      isThreeLine: true,
    );
  }
}

class _MetricTab extends StatelessWidget {
  const _MetricTab({
    required this.title,
    required this.icon,
    required this.metrics,
  });

  final String title;
  final IconData icon;
  final List<_MetricRow> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return AksharaEmptyState(
        message: 'No $title data available for this student.',
        icon: icon,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(metrics.first.label),
                trailing: Text(
                  metrics.first.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              for (final metric in metrics.skip(1))
                ListTile(
                  dense: true,
                  title: Text(metric.label),
                  trailing: Text(
                    metric.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunicationTab extends StatelessWidget {
  const _CommunicationTab({
    required this.communication,
    required this.timeline,
  });

  final Map<String, dynamic> communication;
  final AsyncValue<dynamic> timeline;

  @override
  Widget build(BuildContext context) {
    final commEvents = timeline.maybeWhen(
      data: (rawEvents) {
        final events = (rawEvents as List).cast<StudentTimelineEvent>();
        return events
            .where((e) =>
                e.sourceModule == 'communication' || e.eventType == 'message')
            .toList();
      },
      orElse: () => const <StudentTimelineEvent>[],
    );

    return ListView(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Communication summary',
                  style: context.aksharaText.titleMedium,
                ),
                const SizedBox(height: 8),
                if (communication['pendingNotices'] != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Pending notices'),
                    trailing: Text('${communication['pendingNotices']}'),
                  ),
                if (communication['unreadMessages'] != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.mail_outlined),
                    title: const Text('Unread messages'),
                    trailing: Text('${communication['unreadMessages']}'),
                  ),
                if (communication.isEmpty)
                  const Text('No communication metrics on file.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Recent activity', style: context.aksharaText.titleMedium),
        if (commEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AksharaSpacing.s2),
            child: AksharaEmptyState(
              message: 'No communication events in the timeline yet.',
              compact: true,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final event in commEvents)
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(event.title),
                    subtitle: Text(event.eventAt),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

List<_MetricRow> _attendanceMetrics(Map<String, dynamic> data) {
  final pct = data['percent'] ?? data['attendancePercent'];
  if (pct == null && data.isEmpty) return [];
  return [
    if (pct != null) _MetricRow('Attendance rate', '$pct%'),
    if (data['presentDays'] != null)
      _MetricRow('Present days', '${data['presentDays']}'),
    if (data['present'] != null) _MetricRow('Present days', '${data['present']}'),
    if (data['absentDays'] != null) _MetricRow('Absent days', '${data['absentDays']}'),
    if (data['absent'] != null) _MetricRow('Absent days', '${data['absent']}'),
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
    if (data['exams'] is List && (data['exams'] as List).isNotEmpty)
      _MetricRow(
        'Latest exam',
        '${(data['exams'] as List).first['exam'] ?? '—'}',
      ),
  ];
}

List<_MetricRow> _homeworkMetrics(Map<String, dynamic> data) {
  final rate = data['completionRate'] ?? data['homeworkCompletionRate'];
  if (rate == null && data.isEmpty) return [];
  return [
    if (rate != null) _MetricRow('Completion rate', '$rate%'),
    if (data['pendingCount'] != null)
      _MetricRow('Pending assignments', '${data['pendingCount']}'),
    if (data['submitted'] != null && data['total'] != null)
      _MetricRow('Submitted', '${data['submitted']}/${data['total']}'),
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
  final outstanding =
      data['outstanding'] ?? data['pendingAmount'] ?? data['pending'];
  return [
    if (outstanding != null) _MetricRow('Outstanding', '₹$outstanding'),
    if (data['paidPercent'] != null) _MetricRow('Paid', '${data['paidPercent']}%'),
    if (data['openInvoices'] != null)
      _MetricRow('Open invoices', '${data['openInvoices']}'),
  ];
}

List<_MetricRow> _behaviourMetrics(Map<String, dynamic> data) {
  if (data.isEmpty) return [];
  final incidents = data['incidents'];
  return [
    if (data['conductScore'] != null)
      _MetricRow('Conduct score', '${data['conductScore']}'),
    if (incidents is List)
      _MetricRow('Incidents on file', '${incidents.length}'),
    if (data['remarks'] != null) _MetricRow('Remarks', '${data['remarks']}'),
  ];
}

List<_MetricRow> _transportMetrics(Map<String, dynamic> data) {
  if (data.isEmpty) return [];
  return [
    if (data['routeName'] != null) _MetricRow('Route', '${data['routeName']}'),
    if (data['stopName'] != null) _MetricRow('Stop', '${data['stopName']}'),
    if (data['vehicleNumber'] != null)
      _MetricRow('Vehicle', '${data['vehicleNumber']}'),
    if (data['pickupTime'] != null)
      _MetricRow('Pickup', '${data['pickupTime']}'),
    if (data['dropTime'] != null) _MetricRow('Drop-off', '${data['dropTime']}'),
  ];
}

List<_MetricRow> _documentsMetrics(Map<String, dynamic> data) {
  final items = data['items'];
  if (items is! List || items.isEmpty) return [];
  final verified = items
      .where((item) => item is Map && item['status'] == 'verified')
      .length;
  return [
    _MetricRow('Documents on file', '${items.length}'),
    _MetricRow('Verified', '$verified'),
    if (items.first is Map && (items.first as Map)['name'] != null)
      _MetricRow('Latest', '${(items.first as Map)['name']}'),
  ];
}

class _MetricRow {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;
}

String _guardianLabel(Map<String, dynamic> parentInformation) {
  final direct = parentInformation['guardianName'];
  if (direct != null) return direct.toString();
  final guardians = parentInformation['guardians'];
  if (guardians is List && guardians.isNotEmpty) {
    final first = guardians.first;
    if (first is Map && first['name'] != null) {
      return first['name'].toString();
    }
  }
  return '—';
}
