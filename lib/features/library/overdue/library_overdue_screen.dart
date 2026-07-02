import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_navigation.dart';
import '../library_providers.dart';
import '../library_workflow_actions.dart';
import '../reports/library_report_exporters.dart';
import '../widgets/library_module_scaffold.dart';

/// LIB-1 — Overdue loans report. Lists the open overdue loans with their accrued
/// fine and exports the grid (CSV / PDF, shared XCT-1 template). Also the home
/// for LIB-5 "Send overdue reminders" and LIB-D1 settings entry.
class LibraryOverdueScreen extends ConsumerWidget {
  const LibraryOverdueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryOverdueLoadingProvider);
    final isError = ref.watch(libraryOverdueErrorProvider);
    final isEmpty = ref.watch(libraryOverdueEmptyProvider);
    final loans = ref.watch(libraryOverdueProvider) ?? const [];

    return LibraryModuleScaffold(
      screen: LibraryScreen.issues,
      showFilterBar: false,
      breadcrumbsOverride: librarySecondaryBreadcrumbs('Overdue loans'),
      body: _buildBody(
        context,
        ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        loans: loans,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<OverdueLoan> loans,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading overdue loans'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load overdue loans.');
    }

    if (isEmpty || loans.isEmpty) {
      return const AksharaEmptyState(
        message: 'No overdue loans — everything is on time.',
        icon: Icons.check_circle_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AksharaSectionHeader(title: 'Overdue loans'),
            ),
            AksharaManageAction(
              permission: Permission.manageLibrary,
              child: Wrap(
                spacing: AksharaSpacing.s2,
                children: [
                  OutlinedButton.icon(
                    key: QaTestKeys.libraryOverdueExportCsvButton,
                    onPressed: () => _export(context, ref, loans, asPdf: false),
                    icon: const Icon(Icons.table_view_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
                  OutlinedButton.icon(
                    key: QaTestKeys.libraryOverdueExportPdfButton,
                    onPressed: () => _export(context, ref, loans, asPdf: true),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s3),
        _OverdueTable(loans: loans),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaManageAction(
          permission: Permission.manageLibrary,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: QaTestKeys.librarySendRemindersButton,
              onPressed: () => sendLibraryOverdueReminders(context, ref),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Send overdue reminders'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<OverdueLoan> loans, {
    required bool asPdf,
  }) async {
    final exporters =
        LibraryReportExporters(ref.read(aksharaReportExportServiceProvider));
    if (asPdf) {
      await exporters.shareOverduePdf(loans);
    } else {
      await exporters.shareOverdueCsv(loans);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Overdue loans ${asPdf ? 'PDF' : 'CSV'} ready (${loans.length} rows)',
        ),
      ),
    );
  }
}

class _OverdueTable extends StatelessWidget {
  const _OverdueTable({required this.loans});

  final List<OverdueLoan> loans;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final loan in loans) ...[
            _OverdueCard(loan: loan),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Overdue loans table, ${loans.length} loans',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Book')),
              DataColumn(label: Text('ISBN')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('Days overdue')),
              DataColumn(label: Text('Accrued fine')),
            ],
            rows: [
              for (final loan in loans)
                DataRow(
                  cells: [
                    DataCell(Text(loan.memberName)),
                    DataCell(Text(_memberTypeLabel(loan.memberType))),
                    DataCell(Text(loan.bookTitle)),
                    DataCell(Text(loan.isbn)),
                    DataCell(Text(loan.dueDate)),
                    DataCell(Text('${loan.daysOverdue}')),
                    DataCell(Text(loan.accruedFine)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _memberTypeLabel(LibraryMemberType type) => switch (type) {
        LibraryMemberType.student => 'Student',
        LibraryMemberType.teacher => 'Teacher',
        LibraryMemberType.staff => 'Staff',
      };
}

class _OverdueCard extends StatelessWidget {
  const _OverdueCard({required this.loan});

  final OverdueLoan loan;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label:
          '${loan.memberName}, ${loan.bookTitle}, ${loan.daysOverdue} days overdue',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loan.memberName, style: text.titleSmall),
              Text(loan.bookTitle, style: text.bodyMedium),
              Text(
                'Due ${loan.dueDate} · ${loan.daysOverdue} days overdue · '
                '${loan.accruedFine} fine',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
