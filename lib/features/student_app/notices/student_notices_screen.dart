import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../dashboard/student_dashboard_provider.dart';
import 'student_notices_provider.dart';
import 'widgets/notice_list_row.dart';
import 'widgets/notices_filter_bar.dart';
import '../../../theme/breakpoints.dart';

/// Student school and class notices — ST-06.
class StudentNoticesScreen extends ConsumerWidget {
  const StudentNoticesScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotices = ref.watch(studentNoticesFutureProvider);
    final asyncDash = ref.watch(studentDashboardFutureProvider);
    final data = ref.watch(studentNoticesProvider);
    final scope = ref.watch(studentNoticeScopeProvider);
    final isLoading = ref.watch(studentNoticesLoadingProvider) ||
        asyncNotices.isLoading ||
        asyncDash.isLoading;
    final hasError = ref.watch(studentNoticesErrorProvider) ||
        asyncNotices.hasError ||
        asyncDash.hasError;
    final identityResolved =
        asyncDash.hasValue && data.studentName.isNotEmpty;

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Notices',
        subtitle: identityResolved
            ? '${data.studentName} · ${data.classLabel}'
            : null,
        unreadNotifications: asyncDash.hasValue ? data.unreadNotifications : 0,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading notices')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load notices right now.',
                  onRetry: () {
                    ref
                        .read(studentNoticesErrorProvider.notifier)
                        .state = false;
                    ref.invalidate(studentNoticesFutureProvider);
                  },
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
                              SizedBox(
                                height: 88,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.notices.length}',
                                        subtitle: 'Total',
                                        accent: KpiAccent.primary,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.urgentCount}',
                                        subtitle: 'Urgent',
                                        accent: KpiAccent.warning,
                                      ),
                                    ),
                                    const SizedBox(width: AksharaSpacing.s2),
                                    Expanded(
                                      child: AksharaKpiCard(
                                        value: '${data.unreadCount}',
                                        subtitle: 'Unread',
                                        accent: KpiAccent.neutral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              NoticesFilterBar(
                                selectedScope: scope,
                                onScopeChanged: (value) => ref
                                    .read(studentNoticeScopeProvider.notifier)
                                    .state = value,
                              ),
                              const SizedBox(height: AksharaSpacing.s3),
                              if (data.notices.isEmpty)
                                const AksharaEmptyState(
                                  message: 'No notices in this filter.',
                                  icon: Icons.campaign_outlined,
                                  compact: true,
                                )
                              else
                                Column(
                                  children: [
                                    for (var i = 0; i < data.notices.length; i++) ...[
                                      NoticeListRow(notice: data.notices[i]),
                                      if (i < data.notices.length - 1)
                                        const SizedBox(
                                          height: AksharaSpacing.s2,
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
