import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/theme_extensions.dart';
import '../../phase4/phase4_providers.dart';
import '../../../theme/spacing.dart';

class HomeworkIntelligenceScreen extends ConsumerStatefulWidget {
  const HomeworkIntelligenceScreen({super.key});

  @override
  ConsumerState<HomeworkIntelligenceScreen> createState() => _HomeworkIntelligenceScreenState();
}

class _HomeworkIntelligenceScreenState extends ConsumerState<HomeworkIntelligenceScreen> {
  final _classController = TextEditingController(text: 'Grade 8');
  final _subjectController = TextEditingController(text: 'Mathematics');
  String _examType = 'unit_test';

  @override
  void dispose() {
    _classController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planArgs = (
      className: _classController.text.trim(),
      subjectName: _subjectController.text.trim(),
      examType: _examType,
    );
    final plan = ref.watch(homeworkIntelligencePlanProvider(planArgs));

    return Scaffold(
      appBar: AppBar(title: const Text('Homework Intelligence')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          TextField(controller: _classController, decoration: const InputDecoration(labelText: 'Class')),
          TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject')),
          DropdownButton<String>(
            value: _examType,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'unit_test', child: Text('unit_test')),
              DropdownMenuItem(value: 'monthly_test', child: Text('monthly_test')),
            ],
            onChanged: (v) => setState(() => _examType = v ?? 'unit_test'),
          ),
          FilledButton(
            onPressed: () => ref.invalidate(homeworkIntelligencePlanProvider),
            child: const Text('Refresh plan'),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await ref.read(homeworkIntelligenceRepositoryProvider).generate(
                    query: ref.read(phase4QueryProvider),
                    className: _classController.text.trim(),
                    subjectName: _subjectController.text.trim(),
                    examType: _examType,
                    apply: true,
                  );
              messenger.showSnackBar(
                SnackBar(content: Text('Applied ${result.homeworkCount ?? 0} homework assignments')),
              );
            },
            child: const Text('Generate & apply homework'),
          ),
          const SizedBox(height: 16),
          plan.when(
            data: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Weak Topics', style: context.aksharaText.titleMedium),
                ...p.weakTopics.map((t) => ListTile(title: Text('${t['topic']}'), subtitle: Text('${t['chapter']}'))),
                Text('Risk Students', style: context.aksharaText.titleMedium),
                ...p.riskStudents.map((s) => ListTile(title: Text('${s['studentName']}'), subtitle: Text('${s['riskLevel']}'))),
                Text('Suggested Homework', style: context.aksharaText.titleMedium),
                ...p.recommendedHomework.map((h) => ListTile(title: Text('${h['title']}'))),
                Text('Suggested Worksheets', style: context.aksharaText.titleMedium),
                ...p.worksheetSuggestions.map((w) => ListTile(title: Text('${w['topic']}'))),
              ],
            ),
            loading: () => const AksharaLoadingState(semanticLabel: 'Loading plan'),
            error: (e, _) => AksharaErrorState.fromFailure(
              apiFailureMapper.fromException(e),
              onRetry: () =>
                  ref.invalidate(homeworkIntelligencePlanProvider(planArgs)),
            ),
          ),
        ],
      ),
    );
  }
}
