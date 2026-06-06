import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../finance_models.dart';
import '../widgets/finance_module_scaffold.dart';
import 'finance_fee_structures_provider.dart';

/// FN-02 — Fee Structures catalog.
class FinanceFeeStructuresScreen extends ConsumerWidget {
  const FinanceFeeStructuresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(financeFeeStructuresLoadingProvider);
    final isError = ref.watch(financeFeeStructuresErrorProvider);
    final isEmpty = ref.watch(financeFeeStructuresEmptyProvider);
    final structures = ref.watch(financeFeeStructuresProvider);
    final academicYear = ref.watch(financeAcademicYearProvider);
    final years = ref.watch(financeAcademicYearsProvider);

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
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Create structure'),
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading fee structures',
              ),
            )
          else if (isError)
            const AksharaErrorState(
              message: 'Unable to load fee structures.',
            )
          else if (isEmpty || structures.isEmpty)
            const AksharaEmptyState(
              message: 'No fee structures for the selected academic year.',
              icon: Icons.receipt_long_outlined,
            )
          else if (AdminLayout.isMobile(context))
            Column(
              children: [
                for (final structure in structures) ...[
                  _FeeStructureCard(structure: structure),
                  const SizedBox(height: AksharaSpacing.s3),
                ],
              ],
            )
          else
            _FeeStructuresTable(structures: structures),
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
    return Semantics(
      label: 'Academic year selector',
      child: Material(
        child: DropdownMenu<String>(
          key: ValueKey(selected),
          initialSelection: selected,
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
  const _FeeStructuresTable({required this.structures});

  final List<FinanceFeeStructure> structures;

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
                      onPressed: () {},
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
  const _FeeStructureCard({required this.structure});

  final FinanceFeeStructure structure;

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
                onPressed: () {},
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
