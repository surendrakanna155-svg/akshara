import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/layout/mobile_dashboard_layout.dart';
import '../../../shared/widgets/widgets.dart';
import '../../adaptive_ai/adaptive_ai_models.dart';
import '../../adaptive_ai/widgets/adaptive_priority_feed.dart';
import '../../auth/auth_provider.dart';
import '../../notifications/notifications_provider.dart';
import '../parent_active_child_provider.dart';
import '../widgets/parent_child_switcher_sheet.dart';
import '../academics/parent_academic_models.dart';
import '../academics/parent_academic_provider.dart';
import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'parent_dashboard_provider.dart';
import 'widgets/event_card.dart';
import 'widgets/notice_carousel.dart';
import 'widgets/parent_reminder_banners.dart';

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
    // WIDGET-001 — honest-async contract: the state comes from the REAL
    // repository call, not from a StateProvider<bool> production never writes.
    final state = ref.watch(parentDashboardViewStateProvider);
    final data = ref.watch(parentDashboardProvider);
    final academic = ref.watch(parentAcademicSummaryProvider);
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final activeChild = ref.watch(parentActiveChildProvider);
    // PAR-D2 — the family view is only meaningful when >1 child is linked.
    final isMultiChild = ref.watch(
      authProvider.select((auth) => auth.linkedChildren.length > 1),
    );

    return Scaffold(
      key: QaTestKeys.parentDashboardScreen,
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        title: AksharaChildSelectorChip(
          key: QaTestKeys.parentChildSelectorChip,
          name: activeChild?.name ?? (state.hasData ? data.childName : ''),
          classLabel:
              activeChild?.classLabel ?? (state.hasData ? data.childClass : ''),
          onTap: () => showParentChildSwitcherSheet(context, ref),
        ),
        unreadNotifications: unreadNotifications,
        showAi: true,
        showProfile: true,
        onAiTap: () => _navigate('ai_copilot'),
        onNotificationsTap: () => _navigate('notifications'),
        onProfileTap: () => _navigate('profile'),
      ),
      body: MobileAsyncBody.fromState(
        state,
        loadingLabel: 'Loading dashboard',
        emptyMessage: 'Your child\'s day will appear here once the school '
            'publishes today\'s records.',
        onRetry: () {
          ref.read(parentDashboardErrorProvider.notifier).state = false;
          ref.invalidate(parentDashboardFutureProvider);
        },
        skeleton: AksharaSkeleton.dashboard(),
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(parentDashboardFutureProvider),
              child: AksharaPremiumBackground(
                motif: AksharaMotif.graduationCap,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: MobileDashboardLayout.screenPadding(width),
                  child: ConstrainedBox(
                    constraints:
                        MobileDashboardLayout.contentConstraints(width),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AksharaGradientHero(
                          eyebrow: data.greetingEyebrow,
                          headline: data.greetingHeadline,
                          motif: AksharaMotif.graduationCap,
                          pills: [
                            for (final chip in data.statusChips)
                              AksharaHeroPill(
                                label: chip.label,
                                tone: _accentForTone(chip.tone),
                              ),
                          ],
                          trailing: _SchoolBadge(schoolName: data.schoolName),
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        _ChildSummaryKpiRow(
                          chips: data.statusChips,
                          todaySummary: data.todaySummary,
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        // PAR-5 — deterministic, multi-type reminder banners from
                        // real module data (fees/PTM/forms/homework/exams).
                        ParentReminderBanners(
                          onActionTap: _navigate,
                        ),
                        // W2 Adaptive AI feed — real own-children items
                        // (attendance/fees), self-hides when empty. onOpenAction
                        // navigates to the module; the parent acts there.
                        const AdaptivePriorityFeedSection(
                          persona: 'parent',
                          onOpenAction: _openParentAdaptiveAction,
                        ),
                        // PAR-D4 — "what needs my action" inbox entry point.
                        AksharaSurfaceListTile(
                          icon: Icons.checklist_outlined,
                          title: 'Action Needed',
                          subtitle:
                              'Fees, meetings, forms & homework that need you',
                          accent: KpiAccent.primary,
                          onTap: () => _navigate('action_inbox'),
                        ),
                        // PAR-D2 — family view (multi-child parents only).
                        if (isMultiChild) ...[
                          const SizedBox(height: AksharaSpacing.s3),
                          AksharaSurfaceListTile(
                            icon: Icons.family_restroom_outlined,
                            title: 'My Children',
                            subtitle:
                                'A snapshot of all your children in one place',
                            accent: KpiAccent.indigo,
                            onTap: () => _navigate('family_view'),
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s3),
                        academic.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => AksharaSectionError(
                            message: 'Academic summary unavailable.',
                            onRetry: () => ref.invalidate(
                              parentAcademicSummaryProvider,
                            ),
                          ),
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
                          accent: KpiAccent.tertiary,
                          onTap: () => _navigate('experience_hub'),
                        ),
                        const SizedBox(height: AksharaSpacing.s3),
                        AksharaSurfaceListTile(
                          icon: Icons.auto_awesome_outlined,
                          title: 'Parent Insights',
                          subtitle:
                              'AI summaries of your child\'s progress, in your language',
                          accent: KpiAccent.indigo,
                          onTap: () => _navigate('parent_insights'),
                        ),
                        if (data.aiInsight.message.isNotEmpty) ...[
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaAiSuggestionBar(
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
                                key: QaTestKeys.parentDashboardQuickAction(
                                  action.id,
                                ),
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

KpiAccent _accentForTone(DashboardChipTone tone) {
  return switch (tone) {
    DashboardChipTone.primary => KpiAccent.primary,
    DashboardChipTone.success => KpiAccent.success,
    DashboardChipTone.warning => KpiAccent.warning,
    DashboardChipTone.error => KpiAccent.error,
  };
}

/// Soft rounded school badge for the hero trailing slot.
/// Map an Adaptive AI recommendation's (logical) deep link to the parent route.
/// The parent lands on the module and acts there — the AI only navigated.
void _openParentAdaptiveAction(BuildContext context, AdaptiveAction action) {
  final link = action.deepLink;
  final route = link.startsWith('/parent/fees')
      ? RouteNames.parentFees
      : link.startsWith('/parent/attendance')
          ? RouteNames.parentAttendance
          : link.startsWith('/parent/homework')
              ? RouteNames.parentHomework
              : RouteNames.parentDashboard;
  context.go(route);
}

class _SchoolBadge extends StatelessWidget {
  const _SchoolBadge({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context) {
    final premium = context.premium;
    return Semantics(
      label: schoolName,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: premium.premiumSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AksharaRadius.lg),
          border: Border.all(color: premium.premiumBorder),
        ),
        child: Icon(
          Icons.school_outlined,
          size: 22,
          color: premium.brandStart,
        ),
      ),
    );
  }
}

class _ChildSummaryKpiRow extends StatelessWidget {
  const _ChildSummaryKpiRow({
    required this.chips,
    required this.todaySummary,
  });

  final List<DashboardStatusChip> chips;
  final List<TodaySummaryItem> todaySummary;

  /// Resolves a KPI value for [kind] from the payload, or null when the
  /// quantity is genuinely unknown.
  ///
  /// The honest-state invariant: `—` means *we do not have this value*. It must
  /// never appear beside the same value rendered for real. The chips are keyed
  /// by typed [DashboardChipKind]; `todaySummary` (which carries its own ids) is
  /// the secondary source, so a payload that reports attendance in either place
  /// produces a value here.
  String? _valueFor(DashboardChipKind kind, String summaryId) {
    for (final chip in chips) {
      if (chip.kind == kind && chip.label.trim().isNotEmpty) {
        return chip.label;
      }
    }
    for (final item in todaySummary) {
      if (item.id == summaryId && item.title.trim().isNotEmpty) {
        return item.title;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final attendance = _valueFor(DashboardChipKind.attendance, 'attendance');
    final fees = _valueFor(DashboardChipKind.fees, 'fees');
    // Homework: a COUNT, so an empty payload must read as unknown, not as a
    // measured zero. When rows exist the count is the number of homework rows.
    final homeworkRows =
        todaySummary.where((t) => t.id.contains('homework')).length;
    final homeworkChip = _valueFor(DashboardChipKind.homework, '__none__');
    final String? homework = homeworkChip ??
        (todaySummary.isEmpty ? null : homeworkRows.toString());

    return Builder(
      builder: (context) {
        final narrow = MediaQuery.sizeOf(context).width < 360;
        // IntrinsicHeight bounds the row to its tallest card so the stretched
        // children get equal, finite heights inside the scroll view.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AksharaPremiumKpiCard(
                  value: truncateStressLabel(attendance ?? '—'),
                  label: 'Attendance',
                  accent: KpiAccent.success,
                  icon: Icons.event_available_outlined,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: AksharaPremiumKpiCard(
                  value: truncateStressLabel(homework ?? '—'),
                  label: narrow ? 'Homework' : 'Homework pending',
                  accent: KpiAccent.warning,
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: AksharaPremiumKpiCard(
                  value: truncateStressLabel(fees ?? '—'),
                  label: narrow ? 'Fees' : 'Fees due',
                  accent: KpiAccent.error,
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Parses a percentage the backend may send as a number, `'92'` or `'92%'`.
/// Returns null for anything that is not a percentage — including the honest
/// placeholders (`'—'`, `'N/A'`, `''`) — so "unknown" stays unknown instead of
/// silently becoming 0.
double? _percentOrNull(Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    final v = raw.toDouble();
    return (v < 0 || v > 100) ? null : v;
  }
  final match =
      RegExp(r'^\s*(\d{1,3}(?:\.\d+)?)\s*%?\s*$').firstMatch(raw.toString());
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || value < 0 || value > 100) return null;
  return value;
}

String _trimPercent(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';

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
    final colors = context.colors;
    final premium = context.premium;
    // Honest-state invariant: a value is either KNOWN (render it, and render
    // the ring/bar at that value) or UNKNOWN (render `—`, and leave the ring
    // silent). Previously the raw value was interpolated as `'$x%'` — which
    // printed the literal `—%` when absent — and the ring fraction came from
    // `double.tryParse` on the *display* string, so a perfectly good `92%`
    // parsed as 0 and the ring contradicted the number printed inside it.
    final attendancePercent = _percentOrNull(summary.attendanceSummary['ratePercent']);
    final homeworkPercent = _percentOrNull(summary.homeworkStatus['completionRate']);
    final gradeRaw = summary.performanceSummary['overallGrade']?.toString().trim();
    final grade = (gradeRaw == null || gradeRaw.isEmpty) ? null : gradeRaw;
    final attendanceLabel =
        attendancePercent == null ? '—' : '${_trimPercent(attendancePercent)}%';
    final homeworkLabel =
        homeworkPercent == null ? '—' : '${_trimPercent(homeworkPercent)}%';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: premium.premiumSurface,
        borderRadius: BorderRadius.circular(AksharaRadius.xxl),
        border: Border.all(color: premium.premiumBorder),
        boxShadow: premium.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Academic progress',
                    style: text.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(child: _ReportLink(onTap: onViewReport)),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Signature data-viz: the headline attendance metric as a
                // premium progress ring in the persona accent.
                AksharaProgressRing(
                  value: (attendancePercent ?? 0) / 100.0,
                  size: 92,
                  strokeWidth: 9,
                  color: attendancePercent == null
                      ? colors.outlineVariant
                      : premium.brandStart,
                  semanticLabel: attendancePercent == null
                      ? 'Attendance not available'
                      : 'Attendance ${_trimPercent(attendancePercent)} percent',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attendanceLabel,
                        style: text.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'Present',
                        style: text.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _stat(context, 'Grade', grade ?? '—'),
                          ),
                          Expanded(
                            child: _stat(context, 'Homework', homeworkLabel),
                          ),
                        ],
                      ),
                      const SizedBox(height: AksharaSpacing.s3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AksharaRadius.xs),
                        child: LinearProgressIndicator(
                          value: ((homeworkPercent ?? 0) / 100.0)
                              .clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: colors.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            homeworkPercent == null
                                ? colors.outlineVariant
                                : premium.brandStart,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.strengths.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                'Strength: ${summary.strengths.first}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final text = context.aksharaText;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: text.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ReportLink extends StatelessWidget {
  const _ReportLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final premium = context.premium;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s2),
        minimumSize: const Size(0, AksharaSpacing.minTouchTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Full report →',
        style: text.labelLarge.copyWith(
          color: premium.brandStart,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
