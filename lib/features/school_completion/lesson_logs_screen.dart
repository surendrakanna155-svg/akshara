import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async/erp_async_state.dart';
import 'lesson_log_dialogs.dart';
import 'school_completion_providers.dart';

/// v13 — real daily-capture: class/subject/topic/outcome come from the actual
/// academic catalog and subject catalog (no more hardcoded demo values), and
/// "mark topic complete" links to a REAL `syllabus_topics.id` instead of a
/// fabricated `topic_${log.id}` that failed the completions FK (P1 fix,
/// caps 58-61 — see `lesson_log_dialogs.dart`).
class LessonLogsScreen extends ConsumerWidget {
  const LessonLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(lessonLogsProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Lesson Logs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLogLessonDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log lesson'),
      ),
      body: ErpAsyncBody(
        state: resolveErpAsync(logs, isDataEmpty: (items) => items.isEmpty),
        loadingLabel: 'Loading lesson logs',
        emptyMessage: 'No lesson logs yet.',
        onRetry: () => ref.invalidate(lessonLogsProvider(null)),
        builder: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final log = items[index];
            return ListTile(
              title: Text(log.topic),
              subtitle: Text('${log.className} · ${log.recordedOn}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'link_topic') {
                    showLinkSyllabusTopicDialog(context, ref, log: log);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'link_topic',
                    child: Text('Link syllabus topic & mark complete'),
                  ),
                ],
                child: Chip(label: Text(lessonOutcomeLabel(log.outcome))),
              ),
            );
          },
        ),
      ),
    );
  }
}
