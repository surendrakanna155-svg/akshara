import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';
import 'subject_form_dialogs.dart';
import '../../core/errors/api_failure_mapper.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Management')),
      floatingActionButton: FloatingActionButton.extended(
        key: QaTestKeys.subjectAddButton,
        onPressed: () => showCreateSubjectDialog(context, ref),
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
                    key: QaTestKeys.subjectRow(s.id),
                    title: Text(s.subjectName),
                    subtitle: Text('${s.subjectCode} · ${s.category} · ${s.status}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${s.gradeLabels.length} grades'),
                        IconButton(
                          key: QaTestKeys.subjectEditButton(s.id),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit subject',
                          onPressed: () =>
                              showEditSubjectDialog(context, ref, subject: s),
                        ),
                      ],
                    ),
                    onTap: () => showEditSubjectDialog(context, ref, subject: s),
                  );
                },
              ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading subjects'),
        error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e), onRetry: () => ref.invalidate(subjectsProvider)),
      ),
    );
  }
}
