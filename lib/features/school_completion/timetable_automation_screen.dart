import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../theme/theme_extensions.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';
import '../../core/errors/error_text.dart';

class TimetableAutomationScreen extends ConsumerStatefulWidget {
  const TimetableAutomationScreen({super.key});

  @override
  ConsumerState<TimetableAutomationScreen> createState() => _TimetableAutomationScreenState();
}

class _TimetableAutomationScreenState extends ConsumerState<TimetableAutomationScreen> {
  TimetableAutomationResult? _result;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable Automation')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          Text('Active subjects', style: context.aksharaText.titleMedium),
          subjects.when(
            data: (items) => Text('${items.length} subjects will drive period allocation'),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(aksharaErrorMessage(e)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _running
                ? null
                : () async {
                    setState(() => _running = true);
                    try {
                      final result = await ref
                          .read(schoolCompletionRepositoryProvider)
                          .automateTimetables(
                            query: ref.read(schoolCompletionQueryProvider),
                            academicYearId: 'year_demo',
                          );
                      setState(() => _result = result);
                    } finally {
                      if (mounted) setState(() => _running = false);
                    }
                  },
            child: _running
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Run automation'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Created ${_result!.timetablesCreated} timetables'),
                    Text('Conflicts: ${_result!.conflictCount}'),
                    const SizedBox(height: 8),
                    Text('Subjects: ${_result!.subjectsUsed.join(', ')}'),
                    if (_result!.warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._result!.warnings.map((w) => Text('⚠ $w')),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
