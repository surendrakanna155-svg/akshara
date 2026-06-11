import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../notifications/notifications_provider.dart';
import '../parent_active_child_provider.dart';
import '../widgets/parent_child_switcher_sheet.dart';
import '../academics/parent_academic_models.dart';
import '../academics/parent_academic_provider.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'parent_dashboard_provider.dart';
import 'widgets/event_card.dart';
import 'widgets/hero_card.dart';
import 'widgets/notice_carousel.dart';

/// Parent home dashboard — PA-01 `PA-01-ParentDashboard-M`.
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({
    super.key,
    this.onNavigate,
  });

  /// Optional route handler; receives action ids from PA-01 prototype map.
  final void Function(String actionId)? onNavigate;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentDashboardProvider);
    final isLoading = ref.watch(parentDashboardLoadingProvider);
    final hasError = ref.watch(parentDashboardErrorProvider);
    final academic = ref.watch(parentAcademicSummaryProvider);
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final activeChild = ref.watch(parentActiveChildProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        title: AksharaChildSelectorChip(
          name: activeChild?.name ?? data.childName,
          classLabel: activeChild?.classLabel ?? data.childClass,
          onTap: () => showParentChildSwitcherSheet(context, ref),
        ),
        unreadNotifications: unreadNotifications,
        showAi: false,
        showProfile: true,
        onNotificationsTap: () => _navigate('notifications'),
        onProfileTap: () => _navigate('profile'),
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load dashboard right now.',
                  onRetry: () =>
                      ref.read(parentDashboardErrorProvider.notifier).state = false,
                )
              : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= _tabletBreakpoint;
                final horizontalPadding = isTablet
                    ? AksharaSpacing.tabletMargin
                    : AksharaSpacing.mobileMargin;

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? _tabletMaxContentWidth : double.infinity,
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
                          HeroCard(
                            eyebrow: data.greetingEyebrow,
                            headline: data.greetingHeadline,
                            schoolName: data.schoolName,
                            statusChips: data.statusChips,
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          academic.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (summary) => _AcademicHeroCard(
                              summary: summary,
                              onViewReport: () => _navigate('academic_report'),
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.school_outlined),
                              title: const Text('Academic summary'),
                              subtitle: const Text(
                                'Attendance, performance, homework & teacher guidance',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _navigate('academic_report'),
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.hub_outlined),
                              title: const Text('Parent Experience Hub'),
                              subtitle: const Text(
                                'Homework status, exam readiness & structured insights',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _navigate('experience_hub'),
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaQuickActionGrid(
                            mobileItemSpacing: AksharaSpacing.s3,
                            children: [
                              for (final action in data.quickActions)
                                AksharaQuickActionCard(
                                  icon: action.icon,
                                  label: action.label,
                                  onTap: () => _navigate(action.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          _TodaySummarySection(
                            items: data.todaySummary,
                            onSeeAll: () => _navigate('today_see_all'),
                            onItemTap: (id) => _navigate(id),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaSectionHeader(
                            title: 'School Notices',
                            trailingLabel: 'See all',
                            onTrailingTap: () => _navigate('notices'),
                          ),
                          const SizedBox(height: AksharaSpacing.s3),
                          NoticeCarousel(
                            notices: data.notices,
                            onNoticeTap: (notice) =>
                                _navigate('notice_${notice.id}'),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaSectionHeader(
                            title: 'Upcoming Events',
                            trailingLabel: 'See all',
                            onTrailingTap: () => _navigate('events'),
                          ),
                          const SizedBox(height: AksharaSpacing.s3),
                          EventCardList(
                            events: data.events,
                            onEventTap: (event) =>
                                _navigate('event_${event.id}'),
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

  void _navigate(String actionId) {
    onNavigate?.call(actionId);
  }
}

class _AcademicHeroCard extends StatelessWidget {
  const _AcademicHeroCard({
    required this.summary,
    required this.onViewReport,
  });

  final ParentAcademicSummary summary;
  final VoidCallback onViewReport;

  @override
  Widget build(BuildContext context) {
    final attendance = summary.attendanceSummary['ratePercent'] ?? '—';
    final grade = summary.performanceSummary['overallGrade'] ?? '—';
    final homework = summary.homeworkStatus['completionRate'] ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AksharaSpacing.s3),
            Row(
              children: [
                Expanded(child: _stat(context, 'Attendance', '$attendance%')),
                Expanded(child: _stat(context, 'Grade', '$grade')),
                Expanded(child: _stat(context, 'Homework', '$homework%')),
              ],
            ),
            if (summary.strengths.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text('Strength: ${summary.strengths.first}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onViewReport, child: const Text('Full report')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TodaySummarySection extends StatelessWidget {
  const _TodaySummarySection({
    required this.items,
    required this.onSeeAll,
    required this.onItemTap,
  });

  final List<TodaySummaryItem> items;
  final VoidCallback onSeeAll;
  final void Function(String id) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaSectionHeader(
          title: 'Today',
          trailingLabel: 'See all',
          onTrailingTap: onSeeAll,
        ),
        const SizedBox(height: AksharaSpacing.s3),
        Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _TodaySummaryRow(
                item: items[i],
                onTap: () => onItemTap(items[i].id),
              ),
              if (i < items.length - 1)
                const SizedBox(height: AksharaSpacing.s3),
            ],
          ],
        ),
      ],
    );
  }
}

class _TodaySummaryRow extends StatelessWidget {
  const _TodaySummaryRow({
    required this.item,
    this.onTap,
  });

  final TodaySummaryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final iconColor = _iconColor(context, item.iconTone);

    return Semantics(
      button: onTap != null,
      label: item.title,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AksharaSpacing.s2),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AksharaSpacing.s2),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
                vertical: AksharaSpacing.s3,
              ),
              child: Row(
                children: [
                  Icon(item.icon, size: 24, color: iconColor),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Text(
                      item.title,
                      style: text.bodyMedium.copyWith(
                        color: colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _iconColor(BuildContext context, DashboardChipTone tone) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (tone) {
      DashboardChipTone.primary => colors.primary,
      DashboardChipTone.success => ext.success,
      DashboardChipTone.warning => ext.warning,
      DashboardChipTone.error => colors.error,
    };
  }
}
