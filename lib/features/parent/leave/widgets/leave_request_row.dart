import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../leave_models.dart';
import 'leave_status_chip.dart';
import 'leave_timeline.dart';

/// Expandable leave history row for PA-12.
class LeaveRequestRow extends StatelessWidget {
  const LeaveRequestRow({
    super.key,
    required this.request,
    this.initiallyExpanded = false,
  });

  final LeaveRequest request;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          '${request.type.label} leave ${request.fromDateLabel} to ${request.toDateLabel}, ${request.status.label}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s1,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AksharaSpacing.s4,
              0,
              AksharaSpacing.s4,
              AksharaSpacing.s4,
            ),
            title: Text(
              '${request.fromDateLabel} – ${request.toDateLabel}',
              style: text.titleSmall.copyWith(color: colors.onSurface),
            ),
            subtitle: Text(
              '${request.type.label} · ${request.submittedLabel}',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
            trailing: LeaveStatusChip(status: request.status),
            children: [
              Text(
                request.reason,
                style: text.bodyMedium.copyWith(color: colors.onSurface),
              ),
              if (request.hasAttachment) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(
                      child: Text(
                        request.attachmentName ?? 'Attachment added',
                        style: text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AksharaSpacing.s3),
              LeaveTimeline(steps: request.timeline),
            ],
          ),
        ),
      ),
    );
  }
}
