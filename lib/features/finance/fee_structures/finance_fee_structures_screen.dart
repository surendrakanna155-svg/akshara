import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../core/repositories/academic/academic_year_label.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';
import '../finance_workflow_actions.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_fee_structures_provider.dart';

/// FN-02 — Fee Structures catalog.
class FinanceFeeStructuresScreen extends ConsumerWidget {
  const FinanceFeeStructuresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(financeFeeStructuresViewStateProvider);
    final academicYear = ref.watch(financeAcademicYearProvider);
    final years = ref.watch(financeAcademicYearsProvider);

    ref.listen<List<String>>(yearOptionsProvider, (_, next) {
      if (next.isEmpty) return;
      final current = ref.read(financeAcademicYearProvider);
      final resolved = resolveAcademicYearSelection(current, next);
      if (!academicYearLabelsEqual(resolved, current)) {
        ref.read(financeAcademicYearProvider.notifier).state = resolved;
      }
    });

    return FinanceModuleScaffold(
      screen: FinanceScreen.feeStructures,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: AksharaSectionHeader(
                  title: 'Fee structure catalog',
                ),
              ),
              AksharaManageAction(
                permission: Permission.manageFinance,
                child: FilledButton.icon(
                  onPressed: () => showCreateFeeStructureDialog(
                    context,
                    ref,
                    academicYear: academicYear,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create structure'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: _AcademicYearSelector(
              years: years,
              selected: academicYear,
              onChanged: (year) =>
                  ref.read(financeAcademicYearProvider.notifier).state = year,
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          FinanceAsyncBody<PaginatedResult<FinanceFeeStructure>>(
            state: viewState,
            loadingLabel: 'Loading fee structures',
            emptyMessage: 'No fee structures for the selected academic year.',
            emptyIcon: Icons.receipt_long_outlined,
            onRetry: () =>
                retryFinanceFuture(ref, financeFeeStructuresFutureProvider),
            builder: (result) {
              final structures = result.items;
              if (AdminLayout.useCardLayout(context)) {
                return Column(
                  children: [
                    for (final structure in structures) ...[
                      _FeeStructureCard(structure: structure, ref: ref),
                      const SizedBox(height: AksharaSpacing.s3),
                    ],
                  ],
                );
              }
              return _FeeStructuresTable(structures: structures, ref: ref);
            },
          ),
        ],
      ),
    );
  }
}

class _AcademicYearSelector extends StatelessWidget {
  const _AcademicYearSelector({
    required this.years,
    required this.selected,
    required this.onChanged,
  });

  final List<String> years;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveSelection = years.isEmpty
        ? normalizeAcademicYearLabel(selected)
        : resolveAcademicYearSelection(selected, years);
    return Semantics(
      label: 'Academic year selector',
      child: Material(
        child: DropdownMenu<String>(
          key: ValueKey('$effectiveSelection-${years.length}'),
          initialSelection: years.isEmpty ? null : effectiveSelection,
          label: const Text('Academic year'),
          dropdownMenuEntries: [
            for (final year in years)
              DropdownMenuEntry(value: year, label: year),
          ],
          onSelected: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _FeeStructuresTable extends StatelessWidget {
  const _FeeStructuresTable({required this.structures, required this.ref});

  final List<FinanceFeeStructure> structures;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Fee structures table, ${structures.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Class range')),
            DataColumn(label: Text('Annual total')),
            DataColumn(label: Text('Categories')),
            DataColumn(label: Text('Installments')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final structure in structures)
              DataRow(
                cells: [
                  DataCell(Text(structure.name)),
                  DataCell(Text(structure.classRange)),
                  DataCell(Text(structure.totalAnnual)),
                  DataCell(Text(_categoriesLabel(structure))),
                  DataCell(Text(structure.installmentOptions.join(', '))),
                  DataCell(_StructureStatusChip(status: structure.status)),
                  DataCell(
                    TextButton(
                      onPressed: () => showEditFeeStructureDialog(
                        context,
                        ref,
                        structure: structure,
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _categoriesLabel(FinanceFeeStructure structure) {
    return structure.categories.map((c) => c.label).join(' · ');
  }
}

class _FeeStructureCard extends StatelessWidget {
  const _FeeStructureCard({required this.structure, required this.ref});

  final FinanceFeeStructure structure;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(structure.name, style: text.titleSmall),
                ),
                _StructureStatusChip(status: structure.status),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              '${structure.classRange} · ${structure.totalAnnual}',
              style: text.bodyMedium,
            ),
            Text(
              _FeeStructuresTable._categoriesLabel(structure),
              style: text.bodySmall,
            ),
            const SizedBox(height: AksharaSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showEditFeeStructureDialog(
                  context,
                  ref,
                  structure: structure,
                ),
                child: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StructureStatusChip extends StatelessWidget {
  const _StructureStatusChip({required this.status});

  final FeeStructureStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      FeeStructureStatus.active => ('Active', KpiAccent.success),
      FeeStructureStatus.inactive => ('Inactive', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}
