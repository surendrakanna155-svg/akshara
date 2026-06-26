import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../director_models.dart';
import '../director_mutations_provider.dart';
import '../director_providers.dart';
import '../../../core/errors/api_failure_mapper.dart';

/// Opens the metric-input editor. These three per-school figures (marketing
/// spend, operating expense, capacity) have no operational source, so the chain
/// owner enters them here — they then drive Revenue (expenses/margin), Marketing
/// (spend/CPL/ROI) and Growth (capacity %). Manage-gated by the caller.
Future<void> showDirectorMetricInputEditor(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _MetricInputEditorSheet(),
    ),
  );
}

class _MetricInputEditorSheet extends ConsumerStatefulWidget {
  const _MetricInputEditorSheet();

  @override
  ConsumerState<_MetricInputEditorSheet> createState() =>
      _MetricInputEditorSheetState();
}

class _MetricInputEditorSheetState
    extends ConsumerState<_MetricInputEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _spend = TextEditingController();
  final _expense = TextEditingController();
  final _capacity = TextEditingController();

  String? _schoolId;
  late String _periodMonth; // YYYY-MM
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _spend.dispose();
    _expense.dispose();
    _capacity.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_schoolId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(directorMutationsProvider.notifier).saveMetricInput(
            draft: DirectorMetricInputDraft(
              schoolId: _schoolId!,
              periodMonth: '$_periodMonth-01',
              marketingSpendInr: _num(_spend),
              operatingExpenseInr: _num(_expense),
              studentCapacity: _num(_capacity).round(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: QaTestKeys.directorMetricInputSavedSnackbar,
          content: Text('Portfolio inputs saved'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolsState = ref.watch(directorSchoolsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AksharaSpacing.s4,
        AksharaSpacing.s0,
        AksharaSpacing.s4,
        AksharaSpacing.s4,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AksharaSectionHeader(title: 'Enter portfolio inputs'),
            const SizedBox(height: AksharaSpacing.s2),
            const Text(
              'Marketing spend, operating expense and capacity have no automatic '
              'source. Enter them per school per month — they power Margin, '
              'Marketing ROI and Capacity in the dashboards.',
            ),
            const SizedBox(height: AksharaSpacing.s4),
            schoolsState.when(
              loading: () => const AksharaLoadingState(),
              error: (error, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
              data: (schools) => DropdownButtonFormField<String>(
                key: QaTestKeys.directorMetricInputSchoolField,
                initialValue: _schoolId,
                decoration: const InputDecoration(labelText: 'School'),
                items: [
                  for (final s in schools)
                    DropdownMenuItem(
                      value: s.schoolId,
                      child: Text(s.schoolName),
                    ),
                ],
                validator: (v) => v == null ? 'Select a school' : null,
                onChanged: (v) => setState(() => _schoolId = v),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextFormField(
              initialValue: _periodMonth,
              decoration: const InputDecoration(
                labelText: 'Month (YYYY-MM)',
                hintText: '2026-06',
              ),
              keyboardType: TextInputType.datetime,
              validator: (v) =>
                  RegExp(r'^\d{4}-\d{2}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Use YYYY-MM',
              onChanged: (v) => _periodMonth = v.trim(),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            _amountField(_spend, 'Marketing spend (₹)'),
            const SizedBox(height: AksharaSpacing.s3),
            _amountField(_expense, 'Operating expense (₹)'),
            const SizedBox(height: AksharaSpacing.s3),
            _amountField(_capacity, 'Student capacity'),
            const SizedBox(height: AksharaSpacing.s4),
            FilledButton.icon(
              key: QaTestKeys.directorMetricInputSaveButton,
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save inputs'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      validator: (v) {
        final parsed = double.tryParse((v ?? '').trim().replaceAll(',', ''));
        if (parsed == null) return 'Enter a number';
        if (parsed < 0) return 'Must be ≥ 0';
        return null;
      },
    );
  }
}
