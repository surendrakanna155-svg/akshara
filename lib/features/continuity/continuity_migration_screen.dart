import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/forms/forms.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../sis/sis_models.dart';
import '../sis/widgets/sis_module_scaffold.dart';
import 'continuity_mutations_provider.dart';

class ContinuityMigrationScreen extends ConsumerStatefulWidget {
  const ContinuityMigrationScreen({super.key});

  @override
  ConsumerState<ContinuityMigrationScreen> createState() =>
      _ContinuityMigrationScreenState();
}

/// (label, helper) for each migration step, used by the shared step indicator.
const _continuitySteps = <(String, String)>[
  ('Scope', 'Teacher, timetable, parent communication'),
  ('Preview', 'Validate impact before executing'),
  ('Execute', 'Apply migration and audit trail'),
];

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
                style: context.aksharaText.titleLarge,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              AksharaStepIndicator(
                stepLabels: [for (final s in _continuitySteps) s.$1],
                currentIndex: _step,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                _continuitySteps[_step].$2,
                style: context.aksharaText.bodyMedium,
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
