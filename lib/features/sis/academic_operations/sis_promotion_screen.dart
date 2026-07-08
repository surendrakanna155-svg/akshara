import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/forms/forms.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../sis_models.dart';
import '../widgets/sis_module_scaffold.dart';
import 'academic_operations_models.dart';
import 'academic_operations_mutations_provider.dart';
import 'academic_operations_providers.dart';

class SisPromotionScreen extends ConsumerStatefulWidget {
  const SisPromotionScreen({super.key});

  @override
  ConsumerState<SisPromotionScreen> createState() => _SisPromotionScreenState();
}

class _SisPromotionScreenState extends ConsumerState<SisPromotionScreen> {
  int _step = 1;
  List<ClassMappingRule> _mappings = const [];

  @override
  Widget build(BuildContext context) {
    final sourceYear = ref.watch(promotionSourceYearProvider);
    final targetYear = ref.watch(promotionTargetYearProvider);
    final suggested = ref.watch(suggestedMappingsFutureProvider);
    final preview = ref.watch(previewYearTransitionProvider);
    final execution = ref.watch(executeYearTransitionProvider);

    suggested.whenData((rows) {
      if (_mappings.isEmpty && rows.isNotEmpty) {
        _mappings = rows;
      }
    });

    return SisModuleScaffold(
      screen: SisScreen.promotion,
      showFilterBar: false,
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Promotion wizard', style: context.aksharaText.titleLarge),
              const SizedBox(height: AksharaSpacing.s3),
              AksharaStepIndicator(
                stepLabels: const [
                  'Years',
                  'Mapping',
                  'Preview',
                  'Approval',
                  'Execute',
                ],
                currentIndex: _step - 1,
              ),
              const SizedBox(height: AksharaSpacing.s4),
              if (_step == 1) _buildYearStep(sourceYear, targetYear),
              if (_step == 2) _buildMappingStep(suggested),
              if (_step == 3) _buildPreviewStep(preview.valueOrNull),
              if (_step == 4) _buildApprovalStep(preview.valueOrNull),
              if (_step == 5) _buildExecutionStep(execution.valueOrNull),
              const SizedBox(height: AksharaSpacing.s4),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _step == 1 ? null : () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  FilledButton(
                    key: QaTestKeys.sisPromotionContinueButton,
                    onPressed: () => _onContinue(sourceYear, targetYear),
                    child: Text(_step == 5 ? 'Finish' : 'Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearStep(String sourceYear, String targetYear) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select source and target academic years',
            style: context.aksharaText.titleMedium),
        const SizedBox(height: AksharaSpacing.s3),
        DropdownButtonFormField<String>(
          key: QaTestKeys.sisPromotionSourceYearField,
          initialValue: sourceYear,
          decoration: const InputDecoration(labelText: 'Source year'),
          items: const [
            DropdownMenuItem(value: '2025–26', child: Text('2025–26')),
            DropdownMenuItem(value: '2026–27', child: Text('2026–27')),
            DropdownMenuItem(value: '2027–28', child: Text('2027–28')),
          ],
          onChanged: (value) {
            if (value == null) return;
            ref.read(promotionSourceYearProvider.notifier).state = value;
            ref.invalidate(suggestedMappingsFutureProvider);
          },
        ),
        const SizedBox(height: AksharaSpacing.s3),
        DropdownButtonFormField<String>(
          key: QaTestKeys.sisPromotionTargetYearField,
          initialValue: targetYear,
          decoration: const InputDecoration(labelText: 'Target year'),
          items: const [
            DropdownMenuItem(value: '2026–27', child: Text('2026–27')),
            DropdownMenuItem(value: '2027–28', child: Text('2027–28')),
            DropdownMenuItem(value: '2028–29', child: Text('2028–29')),
          ],
          onChanged: (value) {
            if (value == null) return;
            ref.read(promotionTargetYearProvider.notifier).state = value;
            ref.invalidate(suggestedMappingsFutureProvider);
          },
        ),
      ],
    );
  }

  Widget _buildMappingStep(AsyncValue<List<ClassMappingRule>> suggested) {
    return ErpAsyncBody(
      state: resolveErpAsync(suggested, isDataEmpty: (_) => false),
      loadingLabel: 'Loading',
      emptyMessage: 'No suggested class mappings available.',
      onRetry: () => ref.invalidate(suggestedMappingsFutureProvider),
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Confirm class mapping rules',
              style: context.aksharaText.titleMedium),
          const SizedBox(height: AksharaSpacing.s3),
          for (var i = 0; i < _mappings.length; i++)
            SwitchListTile(
              value: _mappings[i].includeStudents,
              title: Text(
                '${_mappings[i].sourceClassLabel}-${_mappings[i].sourceSection}'
                ' -> ${_mappings[i].targetClassLabel}-${_mappings[i].targetSection}',
              ),
              onChanged: (value) {
                setState(() {
                  _mappings = [
                    for (var j = 0; j < _mappings.length; j++)
                      if (i == j)
                        ClassMappingRule(
                          sourceClassLabel: _mappings[j].sourceClassLabel,
                          sourceSection: _mappings[j].sourceSection,
                          targetClassLabel: _mappings[j].targetClassLabel,
                          targetSection: _mappings[j].targetSection,
                          includeStudents: value,
                        )
                      else
                        _mappings[j],
                  ];
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(AcademicTransitionJob? preview) {
    if (preview == null) {
      return const Text('Generate preview to see affected students.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Preview affected students',
            style: context.aksharaText.titleMedium),
        const SizedBox(height: AksharaSpacing.s3),
        for (final row in preview.previewRows)
          ListTile(
            key: QaTestKeys.sisPromotionPreviewRow(row.studentId),
            dense: true,
            title: Text(row.studentName),
            subtitle: Text(
              '${row.fromClassLabel}-${row.fromSection} -> '
              '${row.toClassLabel}-${row.toSection}',
            ),
          ),
      ],
    );
  }

  Widget _buildApprovalStep(AcademicTransitionJob? preview) {
    final count = preview?.previewRows.length ?? 0;
    final requiresApproval = count > 25;
    return Container(
      padding: const EdgeInsets.all(AksharaSpacing.s3),
      color: requiresApproval
          ? context.colors.errorContainer
          : context.colors.primaryContainer,
      child: Text(
        requiresApproval
            ? 'Principal approval required for $count students.'
            : 'Approval not required for $count students.',
      ),
    );
  }

  Widget _buildExecutionStep(AcademicTransitionExecutionReport? report) {
    if (report == null) {
      return const Text('Execute the transition to complete promotion.');
    }
    return Text(
      'Execution complete: ${report.executedCount} moved, '
      '${report.skippedCount} skipped.',
      key: QaTestKeys.sisPromotionExecutionSummary,
    );
  }

  Future<void> _onContinue(String sourceYear, String targetYear) async {
    if (_step == 2) {
      final preview = await ref
          .read(previewYearTransitionProvider.notifier)
          .execute(
            sourceYearId: sourceYear,
            targetYearId: targetYear,
            mappings: _mappings,
          );
      if (preview == null || !mounted) return;
      setState(() => _step = 3);
      return;
    }
    if (_step == 5) {
      final jobId = ref.read(promotionJobIdProvider);
      if (jobId == null) return;
      await ref.read(executeYearTransitionProvider.notifier).execute(jobId: jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promotion execution completed.')),
        );
      }
      return;
    }
    setState(() => _step++);
  }
}
