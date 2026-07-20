import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../library_providers.dart';
import '../library_workflow_actions.dart';
import '../widgets/library_module_scaffold.dart';

/// LB-04 — Return Books.
class LibraryReturnsScreen extends ConsumerWidget {
  const LibraryReturnsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'With fines',
    'Damaged',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryReturnsLoadingProvider);
    final isError = ref.watch(libraryReturnsErrorProvider);
    final isEmpty = ref.watch(libraryReturnsEmptyProvider);
    final returns = ref.watch(libraryFilteredReturnsProvider);
    final filterIndex = ref.watch(libraryReturnsFilterProvider);
    final pageResult = ref.watch(libraryReturnsPageResultProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.returns,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryReturnsFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: FilledButton.icon(
          key: QaTestKeys.libraryReturnScanButton,
          onPressed: () => showReturnLibraryBookDialog(context, ref),
          icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
          label: const Text('Scan return'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        returns: returns,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<LibraryReturnRecord> returns,
    required PaginatedResult<LibraryReturnRecord>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading return records'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load return records.',
      );
    }

    if (isEmpty || returns.isEmpty) {
      return const AksharaEmptyState(
        message: 'No returns match the selected filters.',
        icon: Icons.assignment_return_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Return books'),
        const SizedBox(height: AksharaSpacing.s3),
        _ReturnsTable(returns: returns),
        AksharaPaginatedListFooter<LibraryReturnRecord>(
          result: pageResult,
          pageProvider: libraryReturnsPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Overdue returns raise a fine that shows in Fines & Payments and can be waived (audit-logged). Configure the library_fine fee head under Finance FN-02.',
          actionLabel: 'Finance fees',
          icon: Icons.account_balance_wallet_outlined,
          semanticLabelPrefix: 'Finance integration',
          onAction: () => context.go(RouteNames.financeFeeStructures),
        ),
      ],
    );
  }
}

class _ReturnsTable extends StatelessWidget {
  const _ReturnsTable({required this.returns});

  final List<LibraryReturnRecord> returns;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final record in returns) ...[
            _ReturnCard(record: record),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Return records table, ${returns.length} returns',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Book')),
              DataColumn(label: Text('ISBN')),
              DataColumn(label: Text('Returned')),
              DataColumn(label: Text('Condition')),
              DataColumn(label: Text('Days overdue')),
              DataColumn(label: Text('Fine')),
            ],
            rows: [
              for (final record in returns)
                DataRow(
                  cells: [
                    DataCell(Text(record.memberName)),
                    DataCell(Text(record.bookTitle)),
                    DataCell(Text(record.isbn)),
                    DataCell(Text(record.returnedDate)),
                    DataCell(_ConditionChip(condition: record.condition)),
                    DataCell(Text('${record.daysOverdue}')),
                    DataCell(Text(record.fineAmount)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.record});

  final LibraryReturnRecord record;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          '${record.memberName} returned ${record.bookTitle}, fine ${record.fineAmount}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.memberName, style: text.titleSmall),
              Text(record.bookTitle, style: text.bodyMedium),
              Text(
                'Returned ${record.returnedDate} · Fine ${record.fineAmount}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _ConditionChip(condition: record.condition),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.condition});

  final LibraryReturnCondition condition;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (condition) {
      LibraryReturnCondition.good => ('Good', KpiAccent.success),
      LibraryReturnCondition.fair => ('Fair', KpiAccent.primary),
      LibraryReturnCondition.damaged => ('Damaged', KpiAccent.error),
      LibraryReturnCondition.lost => ('Lost', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Condition: $label',
    );
  }
}
