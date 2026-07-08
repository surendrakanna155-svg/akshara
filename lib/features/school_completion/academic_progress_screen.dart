import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

/// v12.8 — Lesson log linkage, topic/chapter completion, pending alerts.
class AcademicProgressScreen extends ConsumerWidget {
  const AcademicProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherProgressProvider);
    final principal = ref.watch(principalAcademicProgressProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Academic Progress'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Teacher'),
              Tab(text: 'Principal'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ErpAsyncBody(
              state: resolveErpAsync(teacher, isDataEmpty: (_) => false),
              loadingLabel: 'Loading',
              emptyMessage: 'No teacher progress data available.',
              onRetry: () => ref.invalidate(teacherProgressProvider),
              builder: (data) => ListView(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                children: [
                  _metric('Coverage', '${data.coveragePercent}%'),
                  _metric('Topics completed', '${data.topicsCompleted}'),
                  _metric('Topics pending', '${data.topicsPending}'),
                  _metric('Chapters', '${data.chaptersCompleted}/${data.chaptersTotal}'),
                  if (data.pendingAlerts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AksharaWarningBanner(
                      message: '${data.pendingAlerts.length} pending syllabus alerts',
                    ),
                    ...data.pendingAlerts.map((a) => ListTile(title: Text(a))),
                  ],
                ],
              ),
            ),
            ErpAsyncBody(
              state: resolveErpAsync(principal, isDataEmpty: (_) => false),
              loadingLabel: 'Loading',
              emptyMessage: 'No principal progress data available.',
              onRetry: () => ref.invalidate(principalAcademicProgressProvider),
              builder: (data) => ListView(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                children: [
                  _metric('Overall coverage', '${data.overallCoveragePercent}%'),
                  const Divider(),
                  ...data.classCoverage.map(
                    (c) => ListTile(
                      title: Text('${c.className} · ${c.subjectId}'),
                      subtitle: Text('${c.pendingTopics} topics pending'),
                      trailing: Text('${c.coveragePercent}%'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _metric(String label, String value) {
  return ListTile(
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
  );
}
