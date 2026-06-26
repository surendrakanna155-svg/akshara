import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../features/intelligence/teacher_effectiveness/teacher_intervention_intelligence.dart';
import '../../features/intelligence/teacher_effectiveness/teacher_intervention_provider.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import 'evolution_providers.dart';
import '../../theme/spacing.dart';

class TeacherAssistantScreen extends ConsumerWidget {
  const TeacherAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(teacherAssistantInsightsProvider);
    final interventions = ref.watch(teacherInterventionsProvider);
    final interventionSuggestions = ref.watch(teacherInterventionSummaryProvider);
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
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            Text('Which students need help?', style: context.aksharaText.titleMedium),
            ...data.riskStudents.map(
              (s) => ListTile(
                title: Text(s['studentName']?.toString() ?? 'Student'),
                subtitle: Text('${s['className']} · ${s['topReason']}'),
                trailing: Chip(label: Text('${s['riskLevel']}')),
              ),
            ),
            const SizedBox(height: 16),
            interventionSuggestions.when(
              data: (summary) => _interventionSuggestionsSection(context, summary),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
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
            Text('Intervention tracker', style: context.aksharaText.titleMedium),
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
              error: (e, _) => AksharaErrorState.fromFailure(
                apiFailureMapper.fromException(e),
                onRetry: () => ref.invalidate(teacherInterventionsProvider),
              ),
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

  Widget _interventionSuggestionsSection(
    BuildContext context,
    TeacherInterventionSummary summary,
  ) {
    if (summary.topSuggestions.isEmpty && summary.classLevelActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intervention suggestions', style: context.aksharaText.titleMedium),
        ListTile(
          dense: true,
          title: Text('${summary.totalSuggestions} students flagged'),
          subtitle: Text('Urgent ${summary.urgentCount} · High ${summary.highCount}'),
        ),
        for (final suggestion in summary.topSuggestions)
          ListTile(
            title: Text('${suggestion.studentName} · ${suggestion.priority.label}'),
            subtitle: Text(
              '${suggestion.className} · ${suggestion.triggerReason}\n'
              '${suggestion.suggestedIntervention}',
            ),
            isThreeLine: true,
          ),
        if (summary.classLevelActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Class-level actions', style: context.aksharaText.titleSmall),
          for (final action in summary.classLevelActions)
            ListTile(dense: true, leading: const Icon(Icons.lightbulb_outline), title: Text(action)),
        ],
      ],
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
