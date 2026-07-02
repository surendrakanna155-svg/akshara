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

/// LB-03 — Issue Books.
class LibraryIssuesScreen extends ConsumerWidget {
  const LibraryIssuesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'Overdue',
    'Students',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryIssuesLoadingProvider);
    final isError = ref.watch(libraryIssuesErrorProvider);
    final isEmpty = ref.watch(libraryIssuesEmptyProvider);
    final issues = ref.watch(libraryFilteredIssuesProvider);
    final filterIndex = ref.watch(libraryIssuesFilterProvider);
    final pageResult = ref.watch(libraryIssuesPageResultProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.issues,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryIssuesFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: FilledButton.icon(
          key: QaTestKeys.libraryIssueScanButton,
          onPressed: () => showIssueLibraryBookDialog(context, ref),
          icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
          label: const Text('Scan ISBN'),
        ),
      ),
      body: _buildBody(
        context,
        ref,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        issues: issues,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<LibraryIssueRecord> issues,
    required PaginatedResult<LibraryIssueRecord>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading issue records'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load issue records.',
      );
    }

    if (isEmpty || issues.isEmpty) {
      return const AksharaEmptyState(
        message: 'No active issues match the selected filters.',
        icon: Icons.swap_horiz_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Issue books'),
        const SizedBox(height: AksharaSpacing.s3),
        _IssuesTable(issues: issues),
        AksharaPaginatedListFooter<LibraryIssueRecord>(
          result: pageResult,
          pageProvider: libraryIssuesPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        // LIB-5 — send in-app overdue reminders to members with overdue loans.
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
        const SizedBox(height: AksharaSpacing.s4),
        AksharaInsightCard(
          message:
              'Students view active loans in Student App (My Books). Use "Send overdue reminders" to notify members with overdue books.',
          actionLabel: 'Student app',
          icon: Icons.school_outlined,
          semanticLabelPrefix: 'Student app integration',
          onAction: () => context.go(RouteNames.studentDashboard),
        ),
      ],
    );
  }
}

class _IssuesTable extends ConsumerWidget {
  const _IssuesTable({required this.issues});

  final List<LibraryIssueRecord> issues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final issue in issues) ...[
            _IssueCard(issue: issue),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Issue records table, ${issues.length} loans',
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
              DataColumn(label: Text('Issued')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final issue in issues)
                DataRow(
                  onSelectChanged: issue.sisStudentId != null
                      ? (_) => context.go(
                            RouteNames.sisStudentDetail(issue.sisStudentId!),
                          )
                      : null,
                  cells: [
                    DataCell(Text(issue.memberName)),
                    DataCell(Text(_memberTypeLabel(issue.memberType))),
                    DataCell(Text(issue.bookTitle)),
                    DataCell(Text(issue.isbn)),
                    DataCell(Text(issue.issuedDate)),
                    DataCell(Text(issue.dueDate)),
                    DataCell(_LoanStatusChip(status: issue.status)),
                    DataCell(_IssueActions(issue: issue)),
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

class _IssueCard extends ConsumerWidget {
  const _IssueCard({required this.issue});

  final LibraryIssueRecord issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      label: '${issue.memberName}, ${issue.bookTitle}, due ${issue.dueDate}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.memberName, style: text.titleSmall),
              Text(issue.bookTitle, style: text.bodyMedium),
              Text('Due ${issue.dueDate}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              _LoanStatusChip(status: issue.status),
              if (issue.status == LibraryLoanStatus.active ||
                  issue.status == LibraryLoanStatus.overdue) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _IssueActions(issue: issue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueActions extends ConsumerWidget {
  const _IssueActions({required this.issue});

  final LibraryIssueRecord issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (issue.status != LibraryLoanStatus.active &&
        issue.status != LibraryLoanStatus.overdue) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AksharaSpacing.s2,
      children: [
        // LIB-4 — renew is offered on active loans only (an overdue loan is
        // returned/paid, not renewed).
        if (issue.status == LibraryLoanStatus.active)
          OutlinedButton(
            key: QaTestKeys.libraryRenewLoanButton(issue.id),
            onPressed: () => renewLibraryLoan(context, ref, issue),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Renew'),
          ),
        OutlinedButton(
          key: QaTestKeys.libraryReturnBookButton(issue.id),
          onPressed: () => returnLibraryIssue(context, ref, issue),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Return'),
        ),
      ],
    );
  }
}

class _LoanStatusChip extends StatelessWidget {
  const _LoanStatusChip({required this.status});

  final LibraryLoanStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      LibraryLoanStatus.active => ('Active', KpiAccent.primary),
      LibraryLoanStatus.overdue => ('Overdue', KpiAccent.warning),
      LibraryLoanStatus.returned => ('Returned', KpiAccent.success),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Loan status: $label',
    );
  }
}
