import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_workflow_actions.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../widgets/hr_module_scaffold.dart';

/// HR-02 — Employees.
class HrEmployeesScreen extends ConsumerWidget {
  const HrEmployeesScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Active',
    'On leave',
    'Teachers',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrEmployeesLoadingProvider);
    final isError = ref.watch(hrEmployeesErrorProvider);
    final isEmpty = ref.watch(hrEmployeesEmptyProvider);
    final pageResult = ref.watch(hrEmployeesPageResultProvider);
    final employees = ref.watch(hrFilteredEmployeesProvider);
    final filterIndex = ref.watch(hrEmployeesFilterProvider);

    return HrModuleScaffold(
      screen: HrScreen.employees,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrEmployeesFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AksharaManageAction(
              permission: Permission.manageHr,
              child: FilledButton.icon(
                key: QaTestKeys.hrCreateEmployeeButton,
                onPressed: () => showCreateHrEmployeeDialog(context, ref),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add employee'),
              ),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _buildBody(
            context,
            ref: ref,
            isLoading: isLoading,
            isError: isError,
            isEmpty: isEmpty,
            employees: employees,
            pageResult: pageResult,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WidgetRef ref,
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<HrEmployee> employees,
    required PaginatedResult<HrEmployee>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading employees'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load employees.');
    }

    if (isEmpty || employees.isEmpty) {
      return const AksharaEmptyState(
        message: 'No employees match the selected filters.',
        icon: Icons.person_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Employee directory'),
        const SizedBox(height: AksharaSpacing.s3),
        _EmployeesTable(employees: employees),
        if (pageResult != null)
          AksharaPaginationBar<HrEmployee>(
            result: pageResult,
            onPageChanged: (page) =>
                ref.read(hrEmployeesPageProvider.notifier).state = page,
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message:
              'Teachers linked to the Teacher app (Priya Sharma, Mrs. Rao, Mr. Patel) sync attendance from TA-01.',
          actionLabel: 'View attendance',
          icon: Icons.link_outlined,
          semanticLabelPrefix: 'Teacher app integration',
          onAction: () => context.go(RouteNames.hrAttendance),
        ),
      ],
    );
  }
}

class _EmployeesTable extends StatelessWidget {
  const _EmployeesTable({required this.employees});

  final List<HrEmployee> employees;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final employee in employees) ...[
            _EmployeeCard(employee: employee),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Code')),
        DataColumn(label: Text('Department')),
        DataColumn(label: Text('Designation')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Status')),
      ],
      rowCount: employees.length,
      dataRowMinHeight: 56,
      semanticLabel: 'Employees table, ${employees.length} staff',
      rowBuilder: (index) {
        final employee = employees[index];
        return DataRow(
          onSelectChanged: (_) => context.go(
            RouteNames.hrEmployeeDetail(employee.id),
          ),
          cells: [
            DataCell(Text(employee.name)),
            DataCell(Text(employee.employeeCode)),
            DataCell(Text(employee.department.name)),
            DataCell(Text(employee.designation)),
            DataCell(Text(employee.phone)),
            DataCell(_EmployeeStatusChip(status: employee.status)),
          ],
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final HrEmployee employee;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Employee ${employee.name}, ${employee.designation}',
      button: true,
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => context.go(RouteNames.hrEmployeeDetail(employee.id)),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(employee.name, style: text.titleSmall),
                    ),
                    _EmployeeStatusChip(status: employee.status),
                  ],
                ),
                Text(employee.designation, style: text.bodySmall),
                Text(
                  '${employee.department.name} · ${employee.employeeCode}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeStatusChip extends StatelessWidget {
  const _EmployeeStatusChip({required this.status});

  final HrEmployeeStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HrEmployeeStatus.active => ('Active', KpiAccent.success),
      HrEmployeeStatus.onLeave => ('On leave', KpiAccent.warning),
      HrEmployeeStatus.probation => ('Probation', KpiAccent.primary),
      HrEmployeeStatus.inactive => ('Inactive', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
