import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';

class LessonAnalyticsScreen extends ConsumerWidget {
  const LessonAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherLessonAnalyticsProvider);
    final principal = ref.watch(principalLessonAnalyticsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lesson Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Teacher view'),
              Tab(text: 'Principal view'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            teacher.when(
              loading: () => const AksharaLoadingState(),
              error: (e, _) => AksharaErrorState(message: '$e'),
              data: (data) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _metricTile('Coverage', '${data.coveragePercent}%'),
                  _metricTile('Completed', '${data.completedLessons}'),
                  _metricTile('Pending', '${data.pendingLessons}'),
                  if (data.upcomingRisk != null)
                    AksharaWarningBanner(message: data.upcomingRisk!),
                  const SizedBox(height: 12),
                  const Text('Pending topics', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...data.pendingTopics.map((t) => ListTile(title: Text(t))),
                ],
              ),
            ),
            principal.when(
              loading: () => const AksharaLoadingState(),
              error: (e, _) => AksharaErrorState(message: '$e'),
              data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text('${item.className} · ${item.subjectId ?? 'All'}'),
                    subtitle: Text(
                      '${item.completedTopics}/${item.totalTopics} topics · ${item.pendingTopics.join(', ')}',
                    ),
                    trailing: Text('${item.coveragePercent}%'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _metricTile(String label, String value) {
  return ListTile(
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
  );
}
