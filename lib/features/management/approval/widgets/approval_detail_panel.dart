import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/approvals/adapters/approval_adapter_registry.dart';
import '../../../../core/approvals/approval_audit.dart';
import '../../../../core/approvals/approval_models.dart';
import '../../../../core/approvals/approval_permissions.dart';
import '../../../../core/approvals/approval_status.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_approve_action.dart';
import '../../../../shared/widgets/akshara_section_header.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../approval_center_actions.dart';
import '../approval_center_provider.dart';
import '../approval_date_format.dart';

/// Detail panel with payload, audit history, and approve/reject actions.
class ApprovalDetailPanel extends ConsumerWidget {
  const ApprovalDetailPanel({
    super.key,
    required this.request,
    this.scrollController,
  });

  final ApprovalRequest request;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final auditAsync = ref.watch(approvalCenterAuditFutureProvider(request.id));

    return Semantics(
      container: true,
      label: 'Approval detail for ${request.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.title,
            style: text.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${request.type.label} · ${request.requesterName}',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          _InfoLine(label: 'Summary', value: request.summary),
          _InfoLine(label: 'Entity', value: '${request.entityType} · ${request.entityId}'),
          _InfoLine(
            label: 'Submitted',
            value: formatApprovalDateTime(request.createdAt),
          ),
          if (request.decidedAt != null) ...[
            _InfoLine(
              label: 'Decided',
              value:
                  '${formatApprovalDate(request.decidedAt!)} by ${request.decidedByName ?? '—'}',
            ),
            if (request.decisionComment != null &&
                request.decisionComment!.isNotEmpty)
              _InfoLine(label: 'Decision note', value: request.decisionComment!),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Request details'),
          const SizedBox(height: AksharaSpacing.s2),
          if (request.payload.isEmpty)
            Text('No additional payload', style: text.bodySmall)
          else
            for (final entry in request.payload.entries)
              _InfoLine(
                label: _labelize(entry.key),
                value: '${entry.value ?? '—'}',
              ),
          ...[
            for (final entry
                in ApprovalAdapterRegistry.enrichDetail(request).entries)
              _InfoLine(label: entry.key, value: entry.value),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Approval history'),
          const SizedBox(height: AksharaSpacing.s2),
          auditAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return Text('No audit entries yet.', style: text.bodySmall);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in entries) _AuditRow(entry: entry),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => Text(
              'Unable to load audit trail.',
              style: text.bodySmall.copyWith(color: colors.error),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          _StatusChip(status: request.status),
          if (request.status == ApprovalStatus.pending) ...[
            const SizedBox(height: AksharaSpacing.s4),
            Row(
              children: [
                AksharaApproveAction(
                  permission: approvalPermissionForType(request.type),
                  child: FilledButton(
                    key: QaTestKeys.approvalApproveButton(request.id),
                    onPressed: () =>
                        approveApprovalRequest(context, ref, request),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s2),
                AksharaApproveAction(
                  permission: approvalPermissionForType(request.type),
                  child: OutlinedButton(
                    key: QaTestKeys.approvalRejectButton(request.id),
                    onPressed: () =>
                        rejectApprovalRequest(context, ref, request),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _labelize(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: text.labelSmall.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final ApprovalAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final actionLabel = switch (entry.action) {
      ApprovalAuditAction.submitted => 'Submitted',
      ApprovalAuditAction.approved => 'Approved',
      ApprovalAuditAction.rejected => 'Rejected',
      ApprovalAuditAction.cancelled => 'Cancelled',
    };
    final timestamp = formatApprovalDateTime(entry.occurredAt);
    final comment = entry.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Text(
        comment == null || comment.isEmpty
            ? '$timestamp · ${entry.actorName}: $actionLabel'
            : '$timestamp · ${entry.actorName}: $actionLabel — $comment',
        style: text.bodySmall,
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
