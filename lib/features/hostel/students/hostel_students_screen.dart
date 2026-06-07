import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_insight_card.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hostel_models.dart';
import '../hostel_providers.dart';
import '../widgets/hostel_module_scaffold.dart';

/// HO-02 — Hostel Students (SIS-linked).
class HostelStudentsScreen extends ConsumerWidget {
  const HostelStudentsScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Resident',
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

    return HostelModuleScaffold(
      screen: HostelScreen.students,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hostelStudentsFilterProvider.notifier).state = index,
      filterTrailing: OutlinedButton.icon(
        onPressed: () => context.go(RouteNames.sisStudents),
        icon: const Icon(Icons.badge_outlined, size: 18),
        label: const Text('SIS registry'),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        students: students,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<HostelStudent> students,
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
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Student names and IDs reference SIS registry. Fee pending links to Finance FN-02 hostel fee structures.',
          actionLabel: 'Open Finance',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'Finance integration',
          onAction: () => context.go(RouteNames.financeFeeStructures),
        ),
      ],
    );
  }
}

class _StudentsTable extends StatelessWidget {
  const _StudentsTable({required this.students});

  final List<HostelStudent> students;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.isMobile(context)) {
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
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});

  final HostelStudent student;

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentStatusChip extends StatelessWidget {
  const _StudentStatusChip({required this.status});

  final HostelStudentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
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
