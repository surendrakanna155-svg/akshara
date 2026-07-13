import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../hostel_workflow_actions.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-02 — Hostel Students (SIS-linked).
class HostelStudentsScreen extends ConsumerWidget {
  const HostelStudentsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Resident',
    'Awaiting',
    'On leave',
    'Checked out',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hostelStudentsLoadingProvider);
    final isError = ref.watch(hostelStudentsErrorProvider);
    final isEmpty = ref.watch(hostelStudentsEmptyProvider);
    final students = ref.watch(hostelFilteredStudentsProvider);
    final filterIndex = ref.watch(hostelStudentsFilterProvider);
    final pageResult = ref.watch(hostelStudentsPageResultProvider);

    return HostelModuleScaffold(
      screen: HostelScreen.students,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hostelStudentsFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaManageAction(
            permission: Permission.manageHostel,
            child: Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: QaTestKeys.hostelAdmitStudentButton,
                  onPressed: () => showAdmitHostelStudentDialog(context, ref),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Admit'),
                ),
                FilledButton.icon(
                  key: QaTestKeys.hostelAssignRoomButton,
                  onPressed: () => showAssignHostelRoomDialog(context, ref),
                  icon: const Icon(Icons.bed_outlined, size: 18),
                  label: const Text('Assign room'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(RouteNames.sisStudents),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('SIS registry'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _buildBody(
            context,
            ref,
            isLoading: isLoading,
            isError: isError,
            isEmpty: isEmpty,
            students: students,
            pageResult: pageResult,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<HostelStudent> students,
    required PaginatedResult<HostelStudent>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading hostel students',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load hostel students.',
      );
    }

    if (isEmpty || students.isEmpty) {
      return const AksharaEmptyState(
        message: 'No hostel students found.',
        icon: Icons.groups_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Hostel residents'),
        const SizedBox(height: AksharaSpacing.s3),
        _StudentsTable(students: students),
        AksharaPaginatedListFooter<HostelStudent>(
          result: pageResult,
          pageProvider: hostelStudentsPageProvider,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Student names and IDs reference the SIS registry. Hostel fees are tracked in the Hostel module and '
              'are NOT posted to the Finance ledger — collect them via the FN-02 hostel fee structures if needed.',
          actionLabel: 'Open Finance',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'Finance integration',
          onAction: () => context.go(RouteNames.financeFeeStructures),
        ),
      ],
    );
  }
}

class _StudentsTable extends ConsumerWidget {
  const _StudentsTable({required this.students});

  final List<HostelStudent> students;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final student in students) ...[
            _StudentCard(student: student),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Hostel students table, ${students.length} residents',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            columns: const [
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Block')),
              DataColumn(label: Text('Room')),
              DataColumn(label: Text('Bed')),
              DataColumn(label: Text('Fee pending')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final student in students)
                DataRow(
                  onSelectChanged: (_) => context.go(
                    RouteNames.sisStudentDetail(student.sisStudentId),
                  ),
                  cells: [
                    DataCell(Text(student.studentName)),
                    DataCell(Text(student.classLabel)),
                    DataCell(Text(student.block)),
                    DataCell(Text(student.room)),
                    DataCell(Text(student.bed)),
                    DataCell(Text(student.feePending)),
                    DataCell(_StudentStatusChip(status: student.status)),
                    DataCell(_StudentActions(student: student)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({required this.student});

  final HostelStudent student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      label: '${student.studentName}, ${student.room}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.studentName, style: text.titleSmall),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Class ${student.classLabel} · ${student.block} ${student.room} ${student.bed}',
                style: text.bodyMedium,
              ),
              Text(
                'Fee pending: ${student.feePending}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              _StudentStatusChip(status: student.status),
              const SizedBox(height: AksharaSpacing.s3),
              _StudentActions(student: student),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentActions extends ConsumerWidget {
  const _StudentActions({required this.student});

  final HostelStudent student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AksharaSpacing.s2,
      runSpacing: AksharaSpacing.s2,
      children: [
        if (student.status == HostelStudentStatus.awaitingAllocation)
          FilledButton(
            key: QaTestKeys.hostelAssignStudentButton(student.id),
            onPressed: () =>
                showAssignHostelRoomDialog(context, ref, student: student),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Assign'),
          ),
        if (student.status == HostelStudentStatus.resident ||
            student.status == HostelStudentStatus.onLeave) ...[
          OutlinedButton(
            key: QaTestKeys.hostelTransferStudentButton(student.id),
            onPressed: () => transferHostelStudentRoom(context, ref, student),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Transfer'),
          ),
          OutlinedButton(
            key: QaTestKeys.hostelCheckoutStudentButton(student.id),
            onPressed: () => checkoutHostelStudent(context, ref, student),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Check out'),
          ),
        ],
      ],
    );
  }
}

class _StudentStatusChip extends StatelessWidget {
  const _StudentStatusChip({required this.status});

  final HostelStudentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HostelStudentStatus.awaitingAllocation =>
        ('Awaiting room', KpiAccent.warning),
      HostelStudentStatus.resident => ('Resident', KpiAccent.success),
      HostelStudentStatus.onLeave => ('On leave', KpiAccent.warning),
      HostelStudentStatus.checkedOut => ('Checked out', KpiAccent.neutral),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Student status: $label',
    );
  }
}
