import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../dashboard/widgets/notice_carousel.dart';
import 'notices_models.dart';
import 'parent_notices_provider.dart';
import 'widgets/notices_filter_bar.dart';

/// Parent school notices — PA-07.
class ParentNoticesScreen extends ConsumerWidget {
  const ParentNoticesScreen({
    super.key,
    this.onNotificationsTap,
    this.onNoticeTap,
  });

  final VoidCallback? onNotificationsTap;
  final void Function(ParentNotice notice)? onNoticeTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentNoticesProvider);
    final category = ref.watch(parentNoticeCategoryProvider);
    final isLoading = ref.watch(parentNoticesLoadingProvider);
    final hasError = ref.watch(parentNoticesErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'School Notices',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        showAi: false,
        trailingPadding: true,
        onAiTap: () {},
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading notices')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load school notices right now.',
                  onRetry: () => ref
                      .read(parentNoticesErrorProvider.notifier)
                      .state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= _tabletBreakpoint;
                    final horizontalPadding = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? _tabletMaxContentWidth
                              : double.infinity,
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            AksharaSpacing.s4,
                            horizontalPadding,
                            AksharaSpacing.s6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NoticesKpiRow(data: data),
                              const SizedBox(height: AksharaSpacing.s4),
                              NoticesFilterBar(
                                selectedCategory: category,
                                onCategoryChanged: (value) => ref
                                    .read(
                                      parentNoticeCategoryProvider.notifier,
                                    )
                                    .state = value,
                              ),
                              const SizedBox(height: AksharaSpacing.s3),
                              if (data.notices.isEmpty)
                                const AksharaEmptyState(
                                  message: 'No notices in this category.',
                                  icon: Icons.campaign_outlined,
                                  compact: true,
                                )
                              else
                                Column(
                                  children: [
                                    for (var i = 0;
                                        i < data.notices.length;
                                        i++) ...[
                                      _NoticeListTile(
                                        notice: data.notices[i],
                                        onTap: onNoticeTap == null
                                            ? null
                                            : () => onNoticeTap!(
                                                  data.notices[i],
                                                ),
                                      ),
                                      if (i < data.notices.length - 1)
                                        const SizedBox(
                                          height: AksharaSpacing.s3,
                                        ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _NoticesKpiRow extends StatelessWidget {
  const _NoticesKpiRow({required this.data});

  final ParentNoticesData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${data.totalCount}',
              subtitle: 'Total',
              accent: KpiAccent.primary,
              icon: Icons.campaign_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.unreadCount}',
              subtitle: 'Unread',
              accent: KpiAccent.warning,
              icon: Icons.mark_email_unread_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.urgentCount}',
              subtitle: 'Urgent',
              accent: KpiAccent.error,
              icon: Icons.priority_high,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeListTile extends StatelessWidget {
  const _NoticeListTile({
    required this.notice,
    this.onTap,
  });

  final ParentNotice notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return NoticeCard(
          notice: notice.toDashboardNotice(),
          width: constraints.maxWidth,
          height: 120,
          onTap: onTap,
        );
      },
    );
  }
}
