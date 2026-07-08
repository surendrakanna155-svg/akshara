import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/async/erp_async_state.dart';
import 'school_completion_providers.dart';
import 'subject_form_dialogs.dart';

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
      body: ErpAsyncBody(
        state: resolveErpAsync(subjects, isDataEmpty: (items) => items.isEmpty),
        loadingLabel: 'Loading subjects',
        emptyMessage: 'No subjects yet. Add your first subject.',
        onRetry: () => ref.invalidate(subjectsProvider),
        builder: (items) => ListView.builder(
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
      ),
    );
  }
}
