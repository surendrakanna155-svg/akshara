import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../core/widgets/whatsapp_contact_button.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_workflow_actions.dart';
import '../hr_models.dart';
import '../hr_navigation.dart';
import '../hr_providers.dart';
import '../widgets/hr_module_scaffold.dart';

/// HR-03 — Employee Profile (child route, not in sub-nav).
class HrEmployeeProfileScreen extends ConsumerWidget {
  const HrEmployeeProfileScreen({
    super.key,
    required this.employeeId,
  });

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrEmployeeProfileLoadingProvider);
    final isError = ref.watch(hrEmployeeProfileErrorProvider);
    final detail = ref.watch(hrEmployeeDetailProvider(employeeId));

    return HrModuleScaffold(
      screen: HrScreen.employees,
      breadcrumbs: detail == null
          ? hrBreadcrumbs(HrScreen.employees)
          : hrEmployeeProfileBreadcrumbs(employeeName: detail.employee.name),
      showFilterBar: false,
      body: _buildBody(
        context,
        ref,
        isLoading: isLoading,
        isError: isError,
        detail: detail,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoading,
    required bool isError,
    required HrEmployeeDetail? detail,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading employee profile'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load employee profile.',
      );
    }

    if (detail == null) {
      return const AksharaEmptyState(
        message: 'Employee not found.',
        icon: Icons.person_off_outlined,
      );
    }

    final employee = detail.employee;
    final text = context.aksharaText;
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Employee profile for ${employee.name}',
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(employee.name, style: text.headlineSmall),
                      ),
                      _ProfileStatusChip(status: employee.status),
                    ],
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(employee.designation, style: text.titleMedium),
                  Text(
                    '${employee.department.name} · ${employee.employeeCode}',
                    style: text.bodyMedium,
                  ),
                  if (employee.classLabel != null)
                    Text(
                      'Class ${employee.classLabel}',
                      style: text.bodySmall,
                    ),
                  const SizedBox(height: AksharaSpacing.s3),
                  Text('Manager: ${detail.reportingManager}',
                      style: text.bodySmall),
                  Text('Email: ${employee.email}', style: text.bodySmall),
                  Text('Phone: ${employee.phone}', style: text.bodySmall),
                  const SizedBox(height: AksharaSpacing.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: WhatsAppContactButton(
                      phone: employee.phone,
                      label: 'Message on WhatsApp',
                      style: WhatsAppButtonStyle.text,
                      message:
                          'Hello ${employee.name}, regarding ${employee.designation} at our school —',
                      unavailableMessage:
                          'No WhatsApp number on file for this staff member.',
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s3),
                  AksharaManageAction(
                    permission: Permission.manageHr,
                    child: Wrap(
                      spacing: AksharaSpacing.s2,
                      runSpacing: AksharaSpacing.s2,
                      children: [
                        OutlinedButton(
                          key: QaTestKeys.hrEditEmployeeButton(employee.id),
                          onPressed: () => showEditHrEmployeeDialog(
                            context,
                            ref,
                            employee: employee,
                          ),
                          child: const Text('Edit'),
                        ),
                        if (employee.status == HrEmployeeStatus.inactive)
                          FilledButton(
                            key: QaTestKeys.hrActivateEmployeeButton(employee.id),
                            onPressed: () => activateHrEmployee(context, ref, employee),
                            child: const Text('Activate'),
                          )
                        else if (employee.status != HrEmployeeStatus.inactive)
                          OutlinedButton(
                            key: QaTestKeys.hrDeactivateEmployeeButton(employee.id),
                            onPressed: () =>
                                deactivateHrEmployee(context, ref, employee),
                            child: const Text('Deactivate'),
                          ),
                        // HR-D2 — probation follow-up: confirm or extend.
                        if (employee.status == HrEmployeeStatus.probation) ...[
                          FilledButton(
                            key: QaTestKeys.hrProbationConfirmAction,
                            onPressed: () =>
                                confirmHrEmployeeProbation(context, ref, employee),
                            child: const Text('Confirm'),
                          ),
                          OutlinedButton(
                            key: QaTestKeys.hrProbationExtendAction,
                            onPressed: () =>
                                extendHrEmployeeProbation(context, ref, employee),
                            child: const Text('Extend probation'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _LeaveBalancesCard(balances: detail.leaveBalances),
          const SizedBox(height: AksharaSpacing.s4),
          _RecentAttendanceCard(records: detail.recentAttendance),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _LeaveBalancesCard(balances: detail.leaveBalances)),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(
                child: _RecentAttendanceCard(records: detail.recentAttendance),
              ),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Documents'),
        const SizedBox(height: AksharaSpacing.s3),
        _DocumentsList(documents: detail.documents),
        if (detail.integrationNotes.isNotEmpty) ...[
          const SizedBox(height: AksharaSpacing.s6),
          const AksharaSectionHeader(title: 'Integrations'),
          const SizedBox(height: AksharaSpacing.s3),
          for (final note in detail.integrationNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
              child: Text(note, style: text.bodySmall),
            ),
        ],
      ],
    );
  }
}

class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip({required this.status});

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

class _LeaveBalancesCard extends StatelessWidget {
  const _LeaveBalancesCard({required this.balances});

  final List<HrEmployeeLeaveBalance> balances;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Leave balances',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Leave balances'),
              const SizedBox(height: AksharaSpacing.s3),
              if (balances.isEmpty)
                Text('No leave policy on record.', style: text.bodySmall),
              for (final balance in balances)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          balance.leaveType.name,
                          style: text.bodyMedium,
                        ),
                      ),
                      Text(
                        '${balance.available - balance.used} left',
                        style: text.titleSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAttendanceCard extends StatelessWidget {
  const _RecentAttendanceCard({required this.records});

  final List<HrAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Recent attendance, ${records.length} records',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AksharaSectionHeader(title: 'Recent attendance'),
              const SizedBox(height: AksharaSpacing.s3),
              if (records.isEmpty)
                Text('No attendance records.', style: text.bodySmall)
              else
                for (final record in records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
                    child: Text(
                      '${record.date}: ${record.checkIn} – ${record.checkOut} (${record.status.name})',
                      style: text.bodySmall,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.documents});

  final List<HrEmployeeDocument> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Semantics(
        container: true,
        label: 'Employee documents, none on record',
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s5),
            child: Text(
              'No documents on record.',
              style: context.aksharaText.bodySmall,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Employee documents, ${documents.length} files',
      child: Card(
        elevation: 0,
        child: Column(
          children: [
            for (var i = 0; i < documents.length; i++) ...[
              ListTile(
                title: Text(documents[i].title),
                subtitle: Text(
                  '${documents[i].uploadedOn} · ${documents[i].status}',
                ),
                trailing: _DocumentExpiryTrailing(document: documents[i]),
              ),
              if (i < documents.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

/// HR-D1 — a "days to expiry" badge for a document that carries an expiry date;
/// falls back to the neutral document icon when the document never expires.
class _DocumentExpiryTrailing extends StatelessWidget {
  const _DocumentExpiryTrailing({required this.document});

  final HrEmployeeDocument document;

  @override
  Widget build(BuildContext context) {
    final expiry = document.expiryDate;
    if (expiry == null || expiry.isEmpty) {
      return const Icon(Icons.description_outlined);
    }
    // Prefer the backend-computed daysToExpiry; derive from the date otherwise.
    final days = document.daysToExpiry ??
        DateTime.tryParse(expiry)?.difference(DateTime.now()).inDays;
    final (label, tone) = switch (days) {
      null => ('Expires $expiry', KpiAccent.neutral),
      final d when d < 0 => ('Expired', KpiAccent.error),
      final d when d <= 30 => ('$d days', KpiAccent.warning),
      final d => ('$d days', KpiAccent.success),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}
