import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../theme/spacing.dart';
import '../sis/sis_models.dart';
import '../sis/widgets/sis_module_scaffold.dart';
import 'continuity_mutations_provider.dart';

class ContinuityMigrationScreen extends ConsumerStatefulWidget {
  const ContinuityMigrationScreen({super.key});

  @override
  ConsumerState<ContinuityMigrationScreen> createState() =>
      _ContinuityMigrationScreenState();
}

class _ContinuityMigrationScreenState
    extends ConsumerState<ContinuityMigrationScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(previewContinuityMigrationProvider);
    final execute = ref.watch(executeContinuityMigrationProvider);

    return SisModuleScaffold(
      screen: SisScreen.continuity,
      showFilterBar: false,
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Continuity migration wizard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Stepper(
                currentStep: _step,
                controlsBuilder: (_, __) => const SizedBox.shrink(),
                steps: const [
                  Step(
                    title: Text('Scope'),
                    content: Text('Teacher, timetable, parent communication'),
                  ),
                  Step(
                    title: Text('Preview'),
                    content: Text('Validate impact before executing'),
                  ),
                  Step(
                    title: Text('Execute'),
                    content: Text('Apply migration and audit trail'),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              if (preview.valueOrNull != null)
                Text(
                  'Plan ${preview.value!.id}: '
                  '${preview.value!.fromClass}-${preview.value!.fromSection} '
                  '-> ${preview.value!.toClass}-${preview.value!.toSection}',
                  key: QaTestKeys.sisContinuityPlanSummary,
                ),
              if (execute.valueOrNull != null)
                Text(
                  'Migration ${execute.value!.migrationId} completed',
                  key: QaTestKeys.sisContinuityExecutionSummary,
                ),
              const SizedBox(height: AksharaSpacing.s3),
              Wrap(
                spacing: AksharaSpacing.s2,
                children: [
                  FilledButton(
                    key: QaTestKeys.sisContinuityPreviewButton,
                    onPressed: () async {
                      await ref
                          .read(previewContinuityMigrationProvider.notifier)
                          .execute();
                      if (mounted) setState(() => _step = 1);
                    },
                    child: const Text('Preview continuity'),
                  ),
                  FilledButton(
                    key: QaTestKeys.sisContinuityExecuteButton,
                    onPressed: preview.valueOrNull == null
                        ? null
                        : () async {
                            await ref
                                .read(executeContinuityMigrationProvider.notifier)
                                .execute(planId: preview.value!.id);
                            if (mounted) setState(() => _step = 2);
                          },
                    child: const Text('Execute continuity'),
                  ),
                ],
              ),
              if (preview.isLoading || execute.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AksharaSpacing.s3),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
