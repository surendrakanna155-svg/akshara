import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../parent_dashboard_provider.dart';

/// Horizontal notice scroller (PA-01 §3 Section/Notices).
class NoticeCarousel extends StatelessWidget {
  const NoticeCarousel({
    super.key,
    required this.notices,
    this.onNoticeTap,
    this.cardWidth = 280,
    this.cardHeight = 108,
  });

  final List<DashboardNotice> notices;
  final void Function(DashboardNotice notice)? onNoticeTap;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return const AksharaSectionEmpty(
        message: 'No school notices right now.',
        icon: Icons.campaign_outlined,
      );
    }

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        itemCount: notices.length,
        separatorBuilder: (_, __) => const SizedBox(width: AksharaSpacing.s3),
        itemBuilder: (context, index) {
          final notice = notices[index];
          return NoticeCard(
            notice: notice,
            width: cardWidth,
            height: cardHeight,
            onTap: onNoticeTap == null ? null : () => onNoticeTap!(notice),
          );
        },
      ),
    );
  }
}

/// Single notice tile inside [NoticeCarousel].
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.notice,
    required this.width,
    required this.height,
    this.onTap,
  });

  final DashboardNotice notice;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: notice.isUrgent
          ? 'Urgent notice: ${notice.title}'
          : notice.title,
      child: Material(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notice.isUrgent) ...[
                    AksharaStatusChip(
                      label: 'Urgent',
                      background: colors.errorContainer,
                      foreground: colors.error,
                      size: AksharaStatusChipSize.compact,
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                  ],
                  Expanded(
                    child: Text(
                      notice.title,
                      style: text.titleSmall.copyWith(
                        color: colors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    notice.dateLabel,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
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
}
