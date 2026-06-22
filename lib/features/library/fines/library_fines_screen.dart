import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_providers.dart';
import '../widgets/library_kpi_row.dart';
import '../widgets/library_module_scaffold.dart';

/// LB-06 — Fines & Payments.
class LibraryFinesScreen extends ConsumerWidget {
  const LibraryFinesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Paid',
    'Finance linked',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryFinesLoadingProvider);
    final isError = ref.watch(libraryFinesErrorProvider);
    final isEmpty = ref.watch(libraryFinesEmptyProvider);
    final data = ref.watch(libraryFinesProvider);
    final fines = ref.watch(libraryFilteredFinesProvider);
    final filterIndex = ref.watch(libraryFinesFilterProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.fines,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryFinesFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: OutlinedButton.icon(
          onPressed: () => context.go(RouteNames.financeFeeStructures),
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          label: const Text('Finance FN-02'),
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        data: data,
        fines: fines,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required LibraryFinesData? data,
    required List<LibraryFine> fines,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading library fines'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load library fines.',
      );
    }

    if (isEmpty || data == null || fines.isEmpty) {
      return const AksharaEmptyState(
        message: 'No fines match the selected filters.',
        icon: Icons.payments_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibraryKpiRow(
          kpis: [
            LibraryKpi(
              id: 'pending',
              value: data.totalPending,
              label: 'Pending fines',
              icon: Icons.pending_outlined,
              accentName: 'warning',
            ),
            const LibraryKpi(
              id: 'count',
              value: '4',
              label: 'Records shown',
              icon: Icons.receipt_long_outlined,
              accentName: 'neutral',
            ),
            const LibraryKpi(
              id: 'finance',
              value: 'FN-02',
              label: 'Fee head',
              icon: Icons.account_balance_wallet_outlined,
              accentName: 'primary',
              detail: 'library_fine placeholder',
            ),
          ],
          desktopColumns: 3,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Overdue fines'),
        const SizedBox(height: AksharaSpacing.s3),
        _FinesTable(fines: fines),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.financeIntegrationNote,
          actionLabel: 'Fee structures',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'Finance integration',
          onAction: () => context.go(data.financeRoute),
        ),
      ],
    );
  }
}

class _FinesTable extends StatelessWidget {
  const _FinesTable({required this.fines});

  final List<LibraryFine> fines;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final fine in fines) ...[
            _FineCard(fine: fine),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Library fines table, ${fines.length} records',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Book')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Days overdue')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Finance')),
            ],
            rows: [
              for (final fine in fines)
                DataRow(
                  onSelectChanged: fine.sisStudentId != null
                      ? (_) => context.go(
                            RouteNames.sisStudentDetail(fine.sisStudentId!),
                          )
                      : null,
                  cells: [
                    DataCell(Text(fine.memberName)),
                    DataCell(Text(fine.bookTitle)),
                    DataCell(Text(fine.amount)),
                    DataCell(Text('${fine.daysOverdue}')),
                    DataCell(_FineStatusChip(status: fine.status)),
                    DataCell(Text(fine.financeLinked ? 'Linked' : '—')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FineCard extends StatelessWidget {
  const _FineCard({required this.fine});

  final LibraryFine fine;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '${fine.memberName}, ${fine.amount}, ${fine.daysOverdue} days overdue',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fine.memberName, style: text.titleSmall),
              Text(fine.bookTitle, style: text.bodyMedium),
              Text(
                '${fine.amount} · ${fine.daysOverdue} days overdue',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _FineStatusChip(status: fine.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _FineStatusChip extends StatelessWidget {
  const _FineStatusChip({required this.status});

  final LibraryFineStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      LibraryFineStatus.pending => ('Pending', KpiAccent.warning),
      LibraryFineStatus.paid => ('Paid', KpiAccent.success),
      LibraryFineStatus.waived => ('Waived', KpiAccent.primary),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Fine status: $label',
    );
  }
}
