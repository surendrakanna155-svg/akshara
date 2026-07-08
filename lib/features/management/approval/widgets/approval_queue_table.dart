import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/approvals/approval_models.dart';
import '../../../../core/approvals/approval_request_type.dart';
import '../../../../core/approvals/approval_status.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../core/approvals/approval_permissions.dart';
import '../../../../core/security/rbac_service.dart';
import '../../../../shared/feedback/akshara_haptics.dart';
import '../../../../shared/widgets/akshara_approve_action.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../approval_center_actions.dart';
import '../approval_center_provider.dart';
import '../approval_date_format.dart';
import 'approval_detail_panel.dart';

/// Desktop table and mobile cards for the unified approval queue.
///
/// P2-UX-2 §2.3 polish: on-card decision facts (the request summary), a
/// server-flagged maker-checker badge (with Approve disabled where the viewer
/// raised the request), type-grouped mobile cards, and swipe-to-decide.
class ApprovalQueueTable extends ConsumerWidget {
  const ApprovalQueueTable({
    super.key,
    required this.items,
  });

  final List<ApprovalRequest> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildGroupedCards(context, ref, items),
      );
    }

    final selection = ref.watch(approvalCenterSelectionProvider);

    return Semantics(
      container: true,
      label: 'Approval queue table, ${items.length} items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 108,
            columns: const [
              DataColumn(label: Text('Select')),
              DataColumn(label: Text('Request')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Requester')),
              DataColumn(label: Text('Submitted')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  selected: selection.contains(item.id),
                  cells: [
                    DataCell(_SelectCheckbox(
                      item: item,
                      selected: selection.contains(item.id),
                    )),
                    // The Request cell carries the on-card decision facts: the
                    // title, its summary, and the maker-checker badge.
                    DataCell(
                      _RequestCell(item: item),
                      onTap: () => _openDetail(ref, item),
                    ),
                    DataCell(
                      Text(item.type.label),
                      onTap: () => _openDetail(ref, item),
                    ),
                    DataCell(
                      Text(item.requesterName),
                      onTap: () => _openDetail(ref, item),
                    ),
                    DataCell(
                      Text(_formatDate(item.createdAt)),
                      onTap: () => _openDetail(ref, item),
                    ),
                    DataCell(_StatusChip(status: item.status)),
                    DataCell(_ApprovalActions(item: item)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// P2-UX-2 §2.3 — group the (already type-sorted) queue into per-type sections
  /// with a header, and make each pending card swipe-to-decide.
  List<Widget> _buildGroupedCards(
    BuildContext context,
    WidgetRef ref,
    List<ApprovalRequest> items,
  ) {
    final counts = <ApprovalRequestType, int>{};
    for (final item in items) {
      counts[item.type] = (counts[item.type] ?? 0) + 1;
    }

    final widgets = <Widget>[];
    ApprovalRequestType? currentType;
    for (final item in items) {
      if (item.type != currentType) {
        currentType = item.type;
        widgets.add(_GroupHeader(type: item.type, count: counts[item.type]!));
      }
      widgets.add(_swipeableCard(context, ref, item));
      widgets.add(const SizedBox(height: AksharaSpacing.s3));
    }
    return widgets;
  }

  Widget _swipeableCard(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest item,
  ) {
    final card = _ApprovalMobileCard(item: item);
    if (item.status != ApprovalStatus.pending) return card;

    // Only surface swipe-to-decide when the viewer actually holds this type's
    // approve authority — the same gate the visible buttons use.
    final canAct = ref
        .watch(rbacServiceProvider)
        .hasPermission(approvalPermissionForType(item.type));
    if (!canAct) return card;

    return Dismissible(
      key: ValueKey('approval_dismiss_${item.id}'),
      background: const _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: KpiAccent.success,
        icon: Icons.check_circle_outline,
        label: 'Approve',
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerRight,
        color: KpiAccent.error,
        icon: Icons.cancel_outlined,
        label: 'Reject',
      ),
      // We never let the widget actually dismiss — the action triggers a queue
      // refresh that removes the (now-decided) row. confirmDismiss doubles as
      // the swipe-gesture handler and always returns false.
      confirmDismiss: (direction) async {
        AksharaHaptics.tick();
        if (direction == DismissDirection.startToEnd) {
          // Swipe-right = approve, guarded by the SERVER maker-checker flag.
          if (item.sodBlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You raised this request — another approver must approve it.',
                ),
              ),
            );
            return false;
          }
          final ok = await _confirmApprove(context, item);
          if (ok && context.mounted) {
            await approveApprovalRequest(context, ref, item);
          }
        } else if (direction == DismissDirection.endToStart) {
          // Swipe-left = reject (prompts for the required reason itself).
          await rejectApprovalRequest(context, ref, item);
        }
        return false;
      },
      child: card,
    );
  }

  static Future<bool> _confirmApprove(
    BuildContext context,
    ApprovalRequest item,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve request?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void _openDetail(WidgetRef ref, ApprovalRequest item) {
    ref.read(approvalCenterSelectedIdProvider.notifier).state = item.id;
  }

  static String _formatDate(DateTime value) => formatApprovalDate(value);
}

/// P2-UX-2 §2.3 — per-type section header in the grouped card queue.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.type, required this.count});

  final ApprovalRequestType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Padding(
      key: QaTestKeys.approvalGroupHeader(type.name),
      padding: const EdgeInsets.only(
        top: AksharaSpacing.s2,
        bottom: AksharaSpacing.s2,
      ),
      child: Row(
        children: [
          Text(
            type.label,
            style: text.labelLarge.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Text(
            '· $count',
            style: text.labelMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// P2-UX-2 §2.3 — the request's on-card decision facts for the desktop table:
/// title + summary + the maker-checker badge.
class _RequestCell extends StatelessWidget {
  const _RequestCell({required this.item});

  final ApprovalRequest item;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: text.bodyMedium),
          if (item.summary.isNotEmpty)
            Text(
              item.summary,
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.sodBlocked) ...[
            const SizedBox(height: AksharaSpacing.s1),
            _MakerCheckerBadge(item: item),
          ],
        ],
      ),
    );
  }
}

/// P2-UX-2 §2.3 — server-flagged maker-checker badge. Rendered purely from the
/// [ApprovalRequest.sodBlocked] flag the backend supplies — no client-side SoD
/// derivation.
class _MakerCheckerBadge extends StatelessWidget {
  const _MakerCheckerBadge({required this.item});

  final ApprovalRequest item;

  @override
  Widget build(BuildContext context) {
    return AksharaStatusChip(
      key: QaTestKeys.approvalMakerCheckerBadge(item.id),
      label: 'You raised this',
      tone: KpiAccent.warning,
    );
  }
}

class _ApprovalMobileCard extends ConsumerWidget {
  const _ApprovalMobileCard({required this.item});

  final ApprovalRequest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.aksharaText;

    return Semantics(
      label: 'Approval: ${item.title}',
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => _showMobileDetail(context, ref, item),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.status == ApprovalStatus.pending)
                      _SelectCheckbox(
                        item: item,
                        selected: ref
                            .watch(approvalCenterSelectionProvider)
                            .contains(item.id),
                      ),
                    Expanded(
                      child: Text(item.title, style: text.titleSmall),
                    ),
                  ],
                ),
                // On-card decision facts (P2-UX-2 §2.3).
                if (item.summary.isNotEmpty) ...[
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(item.summary, style: text.bodyMedium),
                ],
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  '${item.requesterName} · ${item.type.label} · ${_formatDate(item.createdAt)}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
                Row(
                  children: [
                    _StatusChip(status: item.status),
                    if (item.sodBlocked) ...[
                      const SizedBox(width: AksharaSpacing.s2),
                      _MakerCheckerBadge(item: item),
                    ],
                  ],
                ),
                if (item.status == ApprovalStatus.pending) ...[
                  const SizedBox(height: AksharaSpacing.s3),
                  _ApprovalActions(item: item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileDetail(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest item,
  ) {
    ref.read(approvalCenterSelectedIdProvider.notifier).state = item.id;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: ApprovalDetailPanel(
            request: item,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) => formatApprovalDate(value);
}

/// PRI-1 — per-row multi-select checkbox. Only pending requests are selectable
/// (only they can be batch-decided); a non-pending row shows a disabled box.
class _SelectCheckbox extends ConsumerWidget {
  const _SelectCheckbox({required this.item, required this.selected});

  final ApprovalRequest item;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectable = item.status == ApprovalStatus.pending;
    return Semantics(
      label: 'Select ${item.title} for batch decision',
      checked: selected,
      child: Checkbox(
        key: QaTestKeys.approvalSelectCheckbox(item.id),
        value: selected,
        onChanged: selectable
            ? (checked) {
                final current = {
                  ...ref.read(approvalCenterSelectionProvider),
                };
                if (checked == true) {
                  current.add(item.id);
                } else {
                  current.remove(item.id);
                }
                ref.read(approvalCenterSelectionProvider.notifier).state =
                    current;
              }
            : null,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      ApprovalStatus.pending => ('Pending', KpiAccent.warning),
      ApprovalStatus.approved => ('Approved', KpiAccent.success),
      ApprovalStatus.rejected => ('Rejected', KpiAccent.error),
      ApprovalStatus.cancelled => ('Cancelled', KpiAccent.neutral),
    };
    return AksharaStatusChip(label: label, tone: tone);
  }
}

class _ApprovalActions extends ConsumerWidget {
  const _ApprovalActions({required this.item});

  final ApprovalRequest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.status != ApprovalStatus.pending) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Approval actions for ${item.title}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AksharaApproveAction(
            permission: approvalPermissionForType(item.type),
            child: Tooltip(
              message: item.sodBlocked
                  ? 'You raised this request — another approver must approve it.'
                  : '',
              child: FilledButton(
                key: QaTestKeys.approvalApproveButton(item.id),
                // Server-flagged self-approval is blocked here so the maker
                // can't even try — the backend enforces the same rule (403).
                onPressed: item.sodBlocked
                    ? null
                    : () => approveApprovalRequest(context, ref, item),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Approve'),
              ),
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          AksharaApproveAction(
            permission: approvalPermissionForType(item.type),
            child: OutlinedButton(
              key: QaTestKeys.approvalRejectButton(item.id),
              onPressed: () => rejectApprovalRequest(context, ref, item),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Reject'),
            ),
          ),
        ],
      ),
    );
  }
}

/// P2-UX-2 §2.3 — the reveal shown behind a card while it is being swiped.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final KpiAccent color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = color.resolve(context).foreground;
    const onTone = Colors.white;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s5),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: onTone),
          const SizedBox(width: AksharaSpacing.s2),
          Text(
            label,
            style: context.aksharaText.labelLarge.copyWith(color: onTone),
          ),
        ],
      ),
    );
  }
}
