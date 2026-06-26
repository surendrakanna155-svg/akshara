import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import 'evolution_providers.dart';
import '../../theme/spacing.dart';

class PrincipalCommandScreen extends ConsumerStatefulWidget {
  const PrincipalCommandScreen({super.key});

  @override
  ConsumerState<PrincipalCommandScreen> createState() => _PrincipalCommandScreenState();
}

class _PrincipalCommandScreenState extends ConsumerState<PrincipalCommandScreen> {
  final _queryController = TextEditingController(text: 'What needs attention today?');
  Map<String, dynamic>? _queryResult;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(principalCommandProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Principal Command Center')),
      body: center.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            Text('Natural language query', style: context.aksharaText.titleMedium),
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Which students are highest risk?',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Attention today'),
                  onPressed: () => _queryController.text = 'What needs attention today?',
                ),
                ActionChip(
                  label: const Text('Highest risk'),
                  onPressed: () => _queryController.text = 'Which students are highest risk?',
                ),
                ActionChip(
                  label: const Text('Overloaded teachers'),
                  onPressed: () => _queryController.text = 'Which teachers are overloaded?',
                ),
                ActionChip(
                  label: const Text('Fee overdue'),
                  onPressed: () => _queryController.text = 'Which fees are overdue?',
                ),
              ],
            ),
            FilledButton(
              onPressed: () async {
                final result = await ref.read(evolutionRepositoryProvider).queryPrincipalCommand(
                      query: ref.read(evolutionQueryProvider),
                      queryText: _queryController.text.trim(),
                    );
                setState(() => _queryResult = result);
              },
              child: const Text('Run query'),
            ),
            if (_queryResult != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Text(_queryResult!['summary']?.toString() ?? ''),
                ),
              ),
            ],
            if (data.priorityEngineScore != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('Priority engine score'),
                  trailing: Text(
                    '${data.priorityEngineScore}/100',
                    style: context.aksharaText.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Top priorities', style: context.aksharaText.titleMedium),
            ...data.topPriorities.map(
              (p) => ListTile(
                leading: const Icon(Icons.priority_high),
                title: Text(p['priority']?.toString() ?? ''),
                trailing: Text('${p['count']}'),
              ),
            ),
            Text('Executive summary', style: context.aksharaText.titleMedium),
            Text(data.executiveSummary),
            Text('Action recommendations', style: context.aksharaText.titleMedium),
            ...data.actionRecommendations.map((a) => ListTile(title: Text(a))),
            Text('Risk overview', style: context.aksharaText.titleMedium),
            Text('Critical: ${data.riskOverview['critical']} · High: ${data.riskOverview['high']}'),
            Text('Widgets', style: context.aksharaText.titleMedium),
            ...data.widgets.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value}'))),
          ],
        ),
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading command center'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load principal command center.',
          onRetry: () => ref.invalidate(principalCommandProvider),
        ),
      ),
    );
  }
}
