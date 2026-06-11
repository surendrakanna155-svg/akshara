import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';

class LessonLogsScreen extends ConsumerWidget {
  const LessonLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(lessonLogsProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Lesson Logs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createLog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log lesson'),
      ),
      body: logs.when(
        data: (items) => items.isEmpty
            ? const AksharaEmptyState(message: 'No lesson logs yet.')
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final log = items[index];
                  return ListTile(
                    title: Text(log.topic),
                    subtitle: Text('${log.className} · ${log.recordedOn}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'complete') {
                          await ref.read(schoolCompletionRepositoryProvider).completeTopic(
                                query: ref.read(schoolCompletionQueryProvider),
                                topicId: 'topic_${log.id}',
                                lessonLogId: log.id,
                              );
                          ref.invalidate(lessonLogsProvider(null));
                          ref.invalidate(teacherProgressProvider);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'complete', child: Text('Mark topic complete')),
                      ],
                      child: Chip(label: Text(log.outcome)),
                    ),
                  );
                },
              ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading lesson logs'),
        error: (e, _) => AksharaErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(lessonLogsProvider(null)),
        ),
      ),
    );
  }

  Future<void> _createLog(BuildContext context, WidgetRef ref) async {
    await ref.read(schoolCompletionRepositoryProvider).createLessonLog(
          query: ref.read(schoolCompletionQueryProvider),
          className: 'Grade 8',
          topic: 'Fractions revision',
          subjectId: 'sub_2',
          outcome: 'completed',
        );
    ref.invalidate(lessonLogsProvider(null));
  }
}
