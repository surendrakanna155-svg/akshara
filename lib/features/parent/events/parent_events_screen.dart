import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../dashboard/widgets/event_card.dart';
import 'events_models.dart';
import 'parent_events_provider.dart';
import '../../../theme/breakpoints.dart';

/// Parent school events — PA-08.
class ParentEventsScreen extends ConsumerWidget {
  const ParentEventsScreen({
    super.key,
    this.onNotificationsTap,
    this.onEventTap,
  });

  final VoidCallback? onNotificationsTap;
  final void Function(ParentEvent event)? onEventTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentEventsProvider);
    final section = ref.watch(parentEventSectionProvider);
    final isLoading = ref.watch(parentEventsLoadingProvider);
    final hasError = ref.watch(parentEventsErrorProvider);
    final sectionEvents = switch (section) {
      EventSection.upcoming => data.upcomingEvents,
      EventSection.past => data.pastEvents,
    };

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'School Events',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        showAi: false,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading events')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load school events right now.',
                  onRetry: () => ref
                      .read(parentEventsErrorProvider.notifier)
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
                              _EventsKpiRow(data: data),
                              const SizedBox(height: AksharaSpacing.s4),
                              _EventSectionControl(
                                selected: section,
                                onChanged: (value) => ref
                                    .read(parentEventSectionProvider.notifier)
                                    .state = value,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              if (sectionEvents.isEmpty)
                                AksharaEmptyState(
                                  message: section == EventSection.upcoming
                                      ? 'No upcoming events scheduled.'
                                      : 'No past events to show.',
                                  icon: Icons.event_busy_outlined,
                                  actionLabel: section == EventSection.upcoming
                                      ? 'View past events'
                                      : 'View upcoming events',
                                  onAction: () {
                                    ref
                                        .read(
                                          parentEventSectionProvider.notifier,
                                        )
                                        .state = section ==
                                            EventSection.upcoming
                                        ? EventSection.past
                                        : EventSection.upcoming;
                                  },
                                  compact: true,
                                )
                              else
                                Material(
                                  color: context.colors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AksharaSpacing.s2,
                                    ),
                                    side: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      for (var i = 0;
                                          i < sectionEvents.length;
                                          i++)
                                        EventCard(
                                          event: sectionEvents[i]
                                              .toDashboardEvent(),
                                          showDivider:
                                              i < sectionEvents.length - 1,
                                          onTap: onEventTap == null
                                              ? null
                                              : () => onEventTap!(
                                                    sectionEvents[i],
                                                  ),
                                        ),
                                    ],
                                  ),
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

class _EventsKpiRow extends StatelessWidget {
  const _EventsKpiRow({required this.data});

  final ParentEventsData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AksharaKpiCard(
              value: '${data.upcomingCount}',
              subtitle: 'Upcoming',
              accent: KpiAccent.primary,
              icon: Icons.event_outlined,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value: '${data.pastCount}',
              subtitle: 'Past',
              accent: KpiAccent.success,
              icon: Icons.history,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Expanded(
            child: AksharaKpiCard(
              value:
                  '${data.upcomingEvents.where((event) => event.isRsvpOpen).length}',
              subtitle: 'RSVP open',
              accent: KpiAccent.warning,
              icon: Icons.how_to_reg_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSectionControl extends StatelessWidget {
  const _EventSectionControl({
    required this.selected,
    required this.onChanged,
  });

  final EventSection selected;
  final ValueChanged<EventSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Event section selector',
      child: SegmentedButton<EventSection>(
        segments: [
          for (final section in EventSection.values)
            ButtonSegment<EventSection>(
              value: section,
              label: Text(section.label),
            ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
