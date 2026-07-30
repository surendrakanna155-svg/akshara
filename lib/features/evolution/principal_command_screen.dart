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
  ConsumerState<PrincipalCommandScreen> createState() =>
      _PrincipalCommandScreenState();
}

class _PrincipalCommandScreenState
    extends ConsumerState<PrincipalCommandScreen> {
  final _queryController =
      TextEditingController(text: 'What needs attention today?');
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
      // DS V2 P4 — persona (admin/indigo) premium canvas behind the command
      // center content.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Principal Command Center')),
      body: AksharaPremiumBackground(
        showMotif: false,
        child: center.when(
          data: (data) => ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              Text('Natural language query',
                  style: context.aksharaText.titleMedium),
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
                    onPressed: () =>
                        _queryController.text = 'What needs attention today?',
                  ),
                  ActionChip(
                    label: const Text('Highest risk'),
                    onPressed: () => _queryController.text =
                        'Which students are highest risk?',
                  ),
                  ActionChip(
                    label: const Text('Overloaded teachers'),
                    onPressed: () => _queryController.text =
                        'Which teachers are overloaded?',
                  ),
                  ActionChip(
                    label: const Text('Fee overdue'),
                    onPressed: () =>
                        _queryController.text = 'Which fees are overdue?',
                  ),
                ],
              ),
              FilledButton(
                onPressed: () async {
                  final result = await ref
                      .read(evolutionRepositoryProvider)
                      .queryPrincipalCommand(
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
                _PriorityScoreCard(score: data.priorityEngineScore!),
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
              Text('Action recommendations',
                  style: context.aksharaText.titleMedium),
              ...data.actionRecommendations
                  .map((a) => ListTile(title: Text(a))),
              Text('Risk overview', style: context.aksharaText.titleMedium),
              Text(
                  'Critical: ${data.riskOverview['critical']} · High: ${data.riskOverview['high']}'),
              Text('Widgets', style: context.aksharaText.titleMedium),
              ...data.widgets.entries.map((e) =>
                  ListTile(title: Text(e.key), trailing: Text('${e.value}'))),
            ],
          ),
          loading: () => const AksharaLoadingState(
              semanticLabel: 'Loading command center'),
          error: (e, _) => AksharaErrorState(
            message: 'Unable to load principal command center.',
            onRetry: () => ref.invalidate(principalCommandProvider),
          ),
        ),
      ),
    );
  }
}

/// DS V2 P4 flagship — the priority-engine score as a premium, health-toned
/// [AksharaProgressRing] (rounded arc over a soft track) replacing the flat
/// "NN/100" list tile. Same metric + 0–100 scale; presentation only. Mirrors the
/// Principal Dashboard school-health ring (primary ≥80 / tertiary ≥60 / error).
class _PriorityScoreCard extends StatelessWidget {
  const _PriorityScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = score >= 80
        ? colors.primary
        : score >= 60
            ? colors.tertiary
            : colors.error;
    return AksharaSurfaceCard(
      semanticLabel: 'Priority engine score $score of 100',
      child: Row(
        children: [
          AksharaProgressRing(
            value: score / 100,
            size: 76,
            strokeWidth: 8,
            color: tone,
            child: Text(
              '$score',
              style: context.aksharaText.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Priority engine score',
                    style: context.aksharaText.titleMedium),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  'Blended urgency across attendance, risk, and fees',
                  style: context.aksharaText.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
