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
class HrLeaveScreen extends ConsumerStatefulWidget {
  const HrLeaveScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  ConsumerState<HrLeaveScreen> createState() => _HrLeaveScreenState();
}

class _HrLeaveScreenState extends ConsumerState<HrLeaveScreen> {
  /// HR-3 — the set of currently multi-selected PENDING leave request ids.
  final Set<String> _selected = <String>{};

  void _toggleSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _clearSelection() {
    if (_selected.isEmpty) return;
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final isLoading = ref.watch(hrLeaveLoadingProvider);
    final isError = ref.watch(hrLeaveErrorProvider);
    final isEmpty = ref.watch(hrLeaveEmptyProvider);
    final data = ref.watch(hrLeaveProvider);
    final requests = ref.watch(hrFilteredLeaveProvider);
    final filterIndex = ref.watch(hrLeaveFilterProvider);
    final leaveApproveState = ref.watch(approveHrLeaveProvider);
    final leaveRejectState = ref.watch(rejectHrLeaveProvider);
    final batchState = ref.watch(batchDecideHrLeaveProvider);
    final isMutating = leaveApproveState.isLoading ||
        leaveRejectState.isLoading ||
        batchState.isLoading;

    // Drop any selected ids that are no longer pending/visible (e.g. after a
    // decision refreshed the list) so the batch bar count stays honest.
    final pendingIds = requests
        .where((r) => r.status == HrLeaveStatus.pending)
        .map((r) => r.id)
        .toSet();
    _selected.retainWhere(pendingIds.contains);

    return HrModuleScaffold(
      screen: HrScreen.leave,
      filters: HrLeaveScreen.filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) {
        _clearSelection();
        ref.read(hrLeaveFilterProvider.notifier).state = index;
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AksharaManageAction(
              permission: Permission.manageHr,
              child: Wrap(
                spacing: AksharaSpacing.s2,
                children: [
                  OutlinedButton.icon(
                    key: QaTestKeys.hrApplyOnBehalfButton,
                    onPressed: () => showApplyLeaveOnBehalfDialog(context, ref),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Apply on behalf'),
                  ),
                  FilledButton.icon(
                    key: QaTestKeys.hrCreateLeaveButton,
                    onPressed: () => showCreateHrLeaveDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New leave'),
                  ),
                ],
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
        if (_selected.isNotEmpty)
          _BatchDecideBar(
            selectedCount: _selected.length,
            isMutating: isMutating,
            onApprove: () => _batchDecide(context, ref, approve: true),
            onReject: () => _batchDecide(context, ref, approve: false),
            onClear: _clearSelection,
          ),
        _LeaveTable(
          requests: requests,
          isMutating: isMutating,
          selected: _selected,
          onToggleSelected: _toggleSelected,
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
        HrSegmentPanel(
          title: 'Leave by type',
          segments: data.leaveByType,
          height: isMobile ? 240 : 280,
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

  Future<void> _batchDecide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    if (_selected.isEmpty) return;
    final ids = _selected.toList(growable: false);
    final comment = await _showCommentDialog(context, approve: approve);
    if (!context.mounted || comment == null) return;

    final result = await ref.read(batchDecideHrLeaveProvider.notifier).execute(
          BatchDecideHrLeaveRequest(
            ids: ids,
            approve: approve,
            reason: comment,
          ),
        );
    if (!context.mounted) return;
    final state = ref.read(batchDecideHrLeaveProvider);
    if (state.hasError || result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to process batch decision.')),
      );
      return;
    }
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.hrBatchDecideSnackbar,
        content: Text(
          '${result.decidedCount} decided, ${result.skippedCount} skipped',
        ),
      ),
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

/// HR-3 — the sticky batch action bar shown while one or more pending rows are
/// multi-selected. manageHr-gated (the whole leave screen already is).
class _BatchDecideBar extends StatelessWidget {
  const _BatchDecideBar({
    required this.selectedCount,
    required this.isMutating,
    required this.onApprove,
    required this.onReject,
    required this.onClear,
  });

  final int selectedCount;
  final bool isMutating;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AksharaManageAction(
      permission: Permission.manageHr,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AksharaSpacing.s3),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$selectedCount selected',
                style: context.aksharaText.titleSmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AksharaSpacing.s2,
                runSpacing: AksharaSpacing.s2,
                children: [
                  TextButton(
                    onPressed: isMutating ? null : onClear,
                    child: const Text('Clear'),
                  ),
                  FilledButton.tonal(
                    key: QaTestKeys.hrBatchRejectButton,
                    onPressed: isMutating ? null : onReject,
                    child: const Text('Reject selected'),
                  ),
                  FilledButton(
                    key: QaTestKeys.hrBatchApproveButton,
                    onPressed: isMutating ? null : onApprove,
                    child: const Text('Approve selected'),
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

class _LeaveTable extends StatelessWidget {
  const _LeaveTable({
    required this.requests,
    required this.isMutating,
    required this.selected,
    required this.onToggleSelected,
    required this.onApprove,
    required this.onReject,
  });

  final List<HrLeaveRequest> requests;
  final bool isMutating;
  final Set<String> selected;
  final void Function(String id, bool selected) onToggleSelected;
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
              isSelected: selected.contains(request.id),
              onToggleSelected: onToggleSelected,
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
              DataColumn(label: Text('')),
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
                    DataCell(
                      request.status == HrLeaveStatus.pending
                          ? AksharaManageAction(
                              permission: Permission.manageHr,
                              child: Checkbox(
                                key: QaTestKeys.hrLeaveSelectCheckbox(request.id),
                                value: selected.contains(request.id),
                                onChanged: isMutating
                                    ? null
                                    : (v) => onToggleSelected(
                                          request.id,
                                          v ?? false,
                                        ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
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
    required this.isSelected,
    required this.onToggleSelected,
    required this.onApprove,
    required this.onReject,
  });

  final HrLeaveRequest request;
  final bool isMutating;
  final bool isSelected;
  final void Function(String id, bool selected) onToggleSelected;
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
                  if (request.status == HrLeaveStatus.pending)
                    AksharaManageAction(
                      permission: Permission.manageHr,
                      child: Checkbox(
                        key: QaTestKeys.hrLeaveSelectCheckbox(request.id),
                        value: isSelected,
                        onChanged: isMutating
                            ? null
                            : (v) => onToggleSelected(request.id, v ?? false),
                      ),
                    ),
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
