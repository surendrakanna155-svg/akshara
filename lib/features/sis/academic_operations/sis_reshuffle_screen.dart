import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../theme/spacing.dart';
import '../sis_models.dart';
import '../widgets/sis_module_scaffold.dart';
import 'academic_operations_mutations_provider.dart';
import 'academic_operations_providers.dart';

class SisReshuffleScreen extends ConsumerWidget {
  const SisReshuffleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(reshufflePreviewFutureProvider);
    final strategy = ref.watch(reshuffleStrategyProvider);
    final mutation = ref.watch(executeOperationPlanProvider);

    return SisModuleScaffold(
      screen: SisScreen.reshuffle,
      showFilterBar: false,
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Student reshuffle', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AksharaSpacing.s3),
              DropdownButtonFormField<String>(
                initialValue: strategy,
                decoration: const InputDecoration(labelText: 'Strategy'),
                items: const [
                  DropdownMenuItem(
                    value: 'alphabetical',
                    child: Text('Alphabetical'),
                  ),
                  DropdownMenuItem(
                    value: 'genderParity',
                    child: Text('Gender Parity'),
                  ),
                  DropdownMenuItem(value: 'merit', child: Text('Merit')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(reshuffleStrategyProvider.notifier).state = value;
                  ref.invalidate(reshufflePreviewFutureProvider);
                },
              ),
              const SizedBox(height: AksharaSpacing.s3),
              preview.when(
                data: (plan) => SizedBox(
                  height: 320,
                  child: ListView(
                    children: [
                      for (final row in plan.previewRows)
                        ListTile(
                          key: QaTestKeys.sisReshufflePreviewRow(row.studentId),
                          title: Text(row.studentName),
                          subtitle: Text(
                            '${row.fromSection} -> ${row.toSection} (${row.reason})',
                          ),
                        ),
                    ],
                  ),
                ),
                loading: () =>
                    const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
                error: (error, _) => SizedBox(
                  height: 320,
                  child: Center(child: Text('Unable to load reshuffle: $error')),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              FilledButton(
                key: QaTestKeys.sisReshuffleExecuteButton,
                onPressed: preview.valueOrNull == null
                    ? null
                    : () async {
                        await ref
                            .read(executeOperationPlanProvider.notifier)
                            .executeReshuffle(planId: preview.value!.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reshuffle completed')),
                          );
                        }
                      },
                child: const Text('Execute reshuffle'),
              ),
              if (mutation.valueOrNull != null)
                Padding(
                  padding: const EdgeInsets.only(top: AksharaSpacing.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moved ${mutation.value!.executedCount} students',
                        key: QaTestKeys.sisReshuffleExecutionSummary,
                      ),
                      TextButton(
                        onPressed: () => context.go(RouteNames.sisContinuity),
                        child: const Text('Run continuity migration'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
