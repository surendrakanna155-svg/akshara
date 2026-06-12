import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/mobile_dashboard_layout.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentDashboardProvider);
    final isLoading = ref.watch(parentDashboardLoadingProvider);
    final hasError = ref.watch(parentDashboardErrorProvider);
    final isEmpty = ref.watch(parentDashboardEmptyProvider);
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
      body: MobileAsyncBody(
        isLoading: isLoading,
        hasError: hasError,
        isEmpty: isEmpty,
        onRetry: () => ref.invalidate(parentDashboardFutureProvider),
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: MobileDashboardLayout.contentConstraints(width),
                child: SingleChildScrollView(
                  padding: MobileDashboardLayout.screenPadding(width),
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
                      _ChildSummaryKpiRow(
                        chips: data.statusChips,
                        todaySummary: data.todaySummary,
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
                      AksharaSurfaceListTile(
                        icon: Icons.hub_outlined,
                        title: 'Parent Experience Hub',
                        subtitle:
                            'Homework status, exam readiness & structured insights',
                        onTap: () => _navigate('experience_hub'),
                      ),
                      if (data.aiInsight.message.isNotEmpty) ...[
                        const SizedBox(height: AksharaSpacing.s4),
                        AksharaInsightCard(
                          message: data.aiInsight.message,
                          actionLabel: data.aiInsight.actionLabel,
                          onAction: () => _navigate('experience_hub'),
                        ),
                      ],
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
                        onEventTap: (event) => _navigate('event_${event.id}'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigate(String actionId) {
    onNavigate?.call(actionId);
  }
}

class _ChildSummaryKpiRow extends StatelessWidget {
  const _ChildSummaryKpiRow({
    required this.chips,
    required this.todaySummary,
  });

  final List<DashboardStatusChip> chips;
  final List<TodaySummaryItem> todaySummary;

  @override
  Widget build(BuildContext context) {
    final attendance = chips
        .where((c) => c.label.toLowerCase().contains('attendance'))
        .map((c) => c.label)
        .firstOrNull;
    final fees = chips
        .where((c) => c.label.toLowerCase().contains('fee'))
        .map((c) => c.label)
        .firstOrNull;
    final homeworkCount = todaySummary
        .where((t) => t.id.contains('homework'))
        .length
        .toString();

    return Row(
      children: [
        Expanded(
          child: AksharaKpiCard(
            value: attendance ?? '—',
            subtitle: 'Attendance',
            accent: KpiAccent.success,
            icon: Icons.event_available_outlined,
            style: AksharaKpiCardStyle.filled,
          ),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: AksharaKpiCard(
            value: homeworkCount,
            subtitle: 'Homework pending',
            accent: KpiAccent.warning,
            icon: Icons.assignment_outlined,
            style: AksharaKpiCardStyle.filled,
          ),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: AksharaKpiCard(
            value: fees ?? '—',
            subtitle: 'Fees due',
            accent: KpiAccent.error,
            icon: Icons.payments_outlined,
            style: AksharaKpiCardStyle.filled,
          ),
        ),
      ],
    );
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
    final text = context.aksharaText;
    final attendance = summary.attendanceSummary['ratePercent'] ?? '—';
    final grade = summary.performanceSummary['overallGrade'] ?? '—';
    final homework = summary.homeworkStatus['completionRate'] ?? '—';

    return AksharaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Academic progress', style: text.titleSmall),
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
            Text(
              'Strength: ${summary.strengths.first}',
              style: text.bodySmall,
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewReport,
              child: const Text('Full report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final text = context.aksharaText;
    return Column(
      children: [
        Text(value, style: text.titleMedium),
        Text(label, style: text.bodySmall),
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

    return AksharaSurfaceCard(
      onTap: onTap,
      semanticLabel: item.title,
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s4,
        vertical: AksharaSpacing.s3,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(item.icon, size: 24, color: iconColor),
            const SizedBox(width: AksharaSpacing.s3),
            Expanded(
              child: Text(
                item.title,
                style: text.bodyMedium.copyWith(color: colors.onSurface),
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
