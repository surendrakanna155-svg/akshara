import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'evolution_providers.dart';

class TeacherAssistantScreen extends ConsumerWidget {
  const TeacherAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(teacherAssistantInsightsProvider);
    final interventions = ref.watch(teacherInterventionsProvider);
    final classFilter = ref.watch(teacherClassFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Assistant'),
        actions: [
          PopupMenuButton<String?>(
            initialValue: classFilter,
            onSelected: (value) => ref.read(teacherClassFilterProvider.notifier).state = value,
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All classes')),
              PopupMenuItem(value: 'Grade 8', child: Text('Grade 8')),
              PopupMenuItem(value: 'Grade 7', child: Text('Grade 7')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ref.read(evolutionRepositoryProvider).createIntervention(
                query: ref.read(evolutionQueryProvider),
                studentId: 'student_1',
                interventionType: 'academic',
                title: 'Schedule doubt-clearing session',
                priority: 'high',
              );
          ref.invalidate(teacherInterventionsProvider);
        },
        label: const Text('Add intervention'),
        icon: const Icon(Icons.add),
      ),
      body: insights.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Which students need help?', style: Theme.of(context).textTheme.titleMedium),
            ...data.riskStudents.map(
              (s) => ListTile(
                title: Text(s['studentName']?.toString() ?? 'Student'),
                subtitle: Text('${s['className']} · ${s['topReason']}'),
                trailing: Chip(label: Text('${s['riskLevel']}')),
              ),
            ),
            const SizedBox(height: 16),
            _section('Weak topics', data.weakTopics),
            _section('Homework concerns', data.homeworkConcerns),
            _section('Lesson plan suggestions', data.lessonPlanSuggestions),
            _section('Parent meeting summaries', data.parentMeetingSummaries),
            _section('Suggested actions', data.suggestedActions),
            if (data.lessonHistory.isNotEmpty)
              _section(
                'Lesson history',
                data.lessonHistory.map((e) => '${e['date']}: ${e['topic']} (${e['outcome']})').toList(),
              ),
            if (data.interventionEffectiveness.isNotEmpty)
              _section(
                'Intervention effectiveness',
                data.interventionEffectiveness
                    .map((e) => '${e['interventionType']}: ${e['effectiveness']}')
                    .toList(),
              ),
            const SizedBox(height: 16),
            Text('Intervention tracker', style: Theme.of(context).textTheme.titleMedium),
            interventions.when(
              data: (items) => items.isEmpty
                  ? const AksharaEmptyState(message: 'No open interventions yet.')
                  : Column(
                      children: items
                          .map(
                            (i) => ListTile(
                              title: Text(i.title),
                              subtitle: Text('${i.interventionType} · ${i.priority}'),
                              trailing: Text(i.status),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading teacher assistant'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load teacher assistant.',
          onRetry: () => ref.invalidate(teacherAssistantInsightsProvider),
        ),
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ...items.map((i) => ListTile(dense: true, title: Text(i))),
        const SizedBox(height: 8),
      ],
    );
  }
}
