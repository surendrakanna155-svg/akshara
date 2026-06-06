import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'attendance_models.dart';

/// PA-02 recent log row — Parent/AttendanceDayRow (358×64).
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    super.key,
    required this.log,
    this.onInfoTap,
  });

  final AttendanceDayLog log;
  final VoidCallback? onInfoTap;

  static const double rowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusStyle = log.status.resolve(context);

    return Semantics(
      button: onInfoTap != null,
      label: '${_formatDate(log.date)} ${statusStyle.label}. ${log.detail}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.chip,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onInfoTap,
          borderRadius: AksharaRadius.chip,
          child: SizedBox(
            height: rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
                vertical: AksharaSpacing.s3,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      _formatDate(log.date),
                      style: text.labelMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  AksharaStatusChip(
                    label: statusStyle.label,
                    background: statusStyle.background,
                    foreground: statusStyle.foreground,
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Text(
                      log.detail,
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onInfoTap,
                    icon: const Icon(Icons.info_outline),
                    iconSize: 20,
                    tooltip: 'Day details',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
