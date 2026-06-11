import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ref.read(schoolCompletionRepositoryProvider).createSubject(
                query: ref.read(schoolCompletionQueryProvider),
                subjectCode: 'NEW',
                subjectName: 'New Subject',
              );
          ref.invalidate(subjectsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add subject'),
      ),
      body: subjects.when(
        data: (items) => items.isEmpty
            ? const AksharaEmptyState(message: 'No subjects yet. Add your first subject.')
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final s = items[index];
                  return ListTile(
                    title: Text(s.subjectName),
                    subtitle: Text('${s.subjectCode} · ${s.category} · ${s.status}'),
                    trailing: Text('${s.gradeLabels.length} grades'),
                  );
                },
              ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading subjects'),
        error: (e, _) => AksharaErrorState(message: '$e', onRetry: () => ref.invalidate(subjectsProvider)),
      ),
    );
  }
}
