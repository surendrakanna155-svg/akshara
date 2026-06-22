import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../phase4/phase4_providers.dart';

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
    final plan = ref.watch(
      homeworkIntelligencePlanProvider((
        className: _classController.text.trim(),
        subjectName: _subjectController.text.trim(),
        examType: _examType,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Homework Intelligence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                Text('Weak Topics', style: Theme.of(context).textTheme.titleMedium),
                ...p.weakTopics.map((t) => ListTile(title: Text('${t['topic']}'), subtitle: Text('${t['chapter']}'))),
                Text('Risk Students', style: Theme.of(context).textTheme.titleMedium),
                ...p.riskStudents.map((s) => ListTile(title: Text('${s['studentName']}'), subtitle: Text('${s['riskLevel']}'))),
                Text('Suggested Homework', style: Theme.of(context).textTheme.titleMedium),
                ...p.recommendedHomework.map((h) => ListTile(title: Text('${h['title']}'))),
                Text('Suggested Worksheets', style: Theme.of(context).textTheme.titleMedium),
                ...p.worksheetSuggestions.map((w) => ListTile(title: Text('${w['topic']}'))),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
