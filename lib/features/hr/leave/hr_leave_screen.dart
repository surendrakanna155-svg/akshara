import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/leave_approval_config.dart';
import '../../management/approval/approval_center_navigation.dart';
import '../../../core/approvals/approval_category.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../hr_mutations_provider.dart';
import '../hr_models.dart';
import '../hr_providers.dart';
import '../hr_requests.dart';
import '../hr_workflow_actions.dart';
import '../widgets/hr_module_scaffold.dart';
import '../widgets/hr_segment_panel.dart';

/// HR-05 — Leave Management.
class HrLeaveScreen extends ConsumerWidget {
  const HrLeaveScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(hrLeaveLoadingProvider);
    final isError = ref.watch(hrLeaveErrorProvider);
    final isEmpty = ref.watch(hrLeaveEmptyProvider);
    final data = ref.watch(hrLeaveProvider);
    final requests = ref.watch(hrFilteredLeaveProvider);
    final filterIndex = ref.watch(hrLeaveFilterProvider);
    final leaveApproveState = ref.watch(approveHrLeaveProvider);
    final leaveRejectState = ref.watch(rejectHrLeaveProvider);
    final isMutating = leaveApproveState.isLoading || leaveRejectState.isLoading;

    return HrModuleScaffold(
      screen: HrScreen.leave,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(hrLeaveFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AksharaManageAction(
              permission: Permission.manageHr,
              child: FilledButton.icon(
                key: QaTestKeys.hrCreateLeaveButton,
                onPressed: () => showCreateHrLeaveDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New leave'),
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
            data: data,
            requests: requests,
            isMutating: isMutating,
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
    required HrLeaveData? data,
    required List<HrLeaveRequest> requests,
    required bool isMutating,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading leave requests'),
      );
    }

    if (isError) {
      return const AksharaErrorState(message: 'Unable to load leave data.');
    }

    if (isEmpty || data == null || requests.isEmpty) {
      return const AksharaEmptyState(
        message: 'No leave requests match the selected filters.',
        icon: Icons.event_busy_outlined,
      );
    }

    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'Leave requests'),
        Text(
          '${data.pendingCount} pending approval',
          style: context.aksharaText.bodySmall,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        _LeaveTable(
          requests: requests,
          isMutating: isMutating,
          onApprove: (request) => _resolveLeaveRequest(
            context,
            ref,
            request: request,
            approve: true,
          ),
          onReject: (request) => _resolveLeaveRequest(
            context,
            ref,
            request: request,
            approve: false,
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (!isMobile)
          HrSegmentPanel(
            title: 'Leave by type',
            segments: data.leaveByType,
            height: 280,
          )
        else
          HrSegmentPanel(
            title: 'Leave by type',
            segments: data.leaveByType,
            height: 240,
          ),
        const SizedBox(height: AksharaSpacing.s6),
        AksharaInsightCard(
          message: data.integrationNote,
          actionLabel: 'View settings',
          icon: Icons.approval_outlined,
          semanticLabelPrefix: 'Leave workflow integration',
          onAction: () => openPrincipalApprovalCenter(
            context,
            ref,
            category: ApprovalCategory.leave,
          ),
        ),
      ],
    );
  }

  Future<void> _resolveLeaveRequest(
    BuildContext context,
    WidgetRef ref, {
    required HrLeaveRequest request,
    required bool approve,
  }) async {
    final comment = await _showCommentDialog(context, approve: approve);
    if (!context.mounted || comment == null) return;

    final mutationRequest = ApproveLeaveRequest(comment: comment);
    if (approve) {
      await ref.read(approveHrLeaveProvider.notifier).execute(
            leaveRequestId: request.id,
            request: mutationRequest,
          );
    } else {
      await ref.read(rejectHrLeaveProvider.notifier).execute(
            leaveRequestId: request.id,
            request: mutationRequest,
          );
    }
    if (!context.mounted) return;
    final mutationState = approve
        ? ref.read(approveHrLeaveProvider)
        : ref.read(rejectHrLeaveProvider);
    if (mutationState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Unable to approve leave request.'
                : 'Unable to reject leave request.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrLeaveApprovalSnackbar,
        content: Text(
          approve
              ? 'Leave request approved.'
              : 'Leave request rejected.',
        ),
      ),
    );
  }

  Future<String?> _showCommentDialog(
    BuildContext context, {
    required bool approve,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve leave' : 'Reject leave'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Comment',
            hintText: 'Add manager note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }
}

class _LeaveTable extends StatelessWidget {
  const _LeaveTable({
    required this.requests,
    required this.isMutating,
    required this.onApprove,
    required this.onReject,
  });

  final List<HrLeaveRequest> requests;
  final bool isMutating;
  final Future<void> Function(HrLeaveRequest request) onApprove;
  final Future<void> Function(HrLeaveRequest request) onReject;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final request in requests) ...[
            _LeaveCard(
              request: request,
              isMutating: isMutating,
              onApprove: onApprove,
              onReject: onReject,
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Leave requests table, ${requests.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('From')),
              DataColumn(label: Text('To')),
              DataColumn(label: Text('Days')),
              DataColumn(label: Text('Approver')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final request in requests)
                DataRow(
                  cells: [
                    DataCell(Text(request.employeeName)),
                    DataCell(Text(request.leaveType.name)),
                    DataCell(Text(request.fromDate)),
                    DataCell(Text(request.toDate)),
                    DataCell(Text('${request.days}')),
                    DataCell(Text(request.approver)),
                    DataCell(_LeaveStatusChip(status: request.status)),
                    DataCell(
                      _LeaveActionButtons(
                        request: request,
                        isMutating: isMutating,
                        onApprove: onApprove,
                        onReject: onReject,
                        compact: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.request,
    required this.isMutating,
    required this.onApprove,
    required this.onReject,
  });

  final HrLeaveRequest request;
  final bool isMutating;
  final Future<void> Function(HrLeaveRequest request) onApprove;
  final Future<void> Function(HrLeaveRequest request) onReject;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Leave request ${request.employeeName}, ${request.days} days',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(request.employeeName, style: text.titleSmall),
                  ),
                  _LeaveStatusChip(status: request.status),
                ],
              ),
              Text(
                '${request.leaveType.name} · ${request.fromDate} – ${request.toDate}',
                style: text.bodySmall,
              ),
              if (request.status == HrLeaveStatus.pending) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _LeaveActionButtons(
                  request: request,
                  isMutating: isMutating,
                  onApprove: onApprove,
                  onReject: onReject,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveActionButtons extends ConsumerWidget {
  const _LeaveActionButtons({
    required this.request,
    required this.isMutating,
    required this.onApprove,
    required this.onReject,
    this.compact = false,
  });

  final HrLeaveRequest request;
  final bool isMutating;
  final Future<void> Function(HrLeaveRequest request) onApprove;
  final Future<void> Function(HrLeaveRequest request) onReject;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (request.status != HrLeaveStatus.pending) {
      return const Text('—');
    }

    if (ref.watch(leaveApprovalRequiredProvider)) {
      return ApprovalCenterRedirectBanner(
        message:
            'Staff leave is approved by the principal in the unified Approval Center.',
        category: ApprovalCategory.leave,
        compact: compact,
      );
    }

    return AksharaManageAction(
      permission: Permission.manageHr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: QaTestKeys.hrApproveLeaveButton(request.id),
            onPressed: isMutating ? null : () => onApprove(request),
            child: const Text('Approve'),
          ),
          TextButton(
            key: QaTestKeys.hrRejectLeaveButton(request.id),
            onPressed: isMutating ? null : () => onReject(request),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _LeaveStatusChip extends StatelessWidget {
  const _LeaveStatusChip({required this.status});

  final HrLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      HrLeaveStatus.pending => ('Pending', KpiAccent.warning),
      HrLeaveStatus.approved => ('Approved', KpiAccent.success),
      HrLeaveStatus.rejected => ('Rejected', KpiAccent.error),
      HrLeaveStatus.cancelled => ('Cancelled', KpiAccent.neutral),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
