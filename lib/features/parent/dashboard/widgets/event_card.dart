import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../parent_dashboard_provider.dart';

/// PA-01 event list row (§3 EventRow · 358×64).
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showDivider = true,
  });

  final DashboardEvent event;
  final VoidCallback? onTap;
  final bool showDivider;

  static const double rowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          label: '${event.title}, ${event.day} ${event.month}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: rowHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AksharaSpacing.s2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _DateBox(day: event.day, month: event.month),
                      const SizedBox(width: AksharaSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              event.title,
                              style: text.titleSmall.copyWith(
                                color: colors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (event.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                event.subtitle!,
                                style: text.bodySmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
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
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.day,
    required this.month,
  });

  final int day;
  final String month;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s1,
        vertical: AksharaSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: AksharaRadius.chip,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: text.titleSmall.copyWith(
                color: colors.onPrimaryContainer,
                height: 1.1,
              ),
            ),
            Text(
              month,
              style: text.labelSmall.copyWith(
                color: colors.onPrimaryContainer,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical list wrapper for multiple [EventCard] items.
class EventCardList extends StatelessWidget {
  const EventCardList({
    super.key,
    required this.events,
    this.onEventTap,
  });

  final List<DashboardEvent> events;
  final void Function(DashboardEvent event)? onEventTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const AksharaSectionEmpty(
        message: 'No upcoming events scheduled.',
        icon: Icons.event_outlined,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          EventCard(
            event: events[i],
            showDivider: i < events.length - 1,
            onTap: onEventTap == null ? null : () => onEventTap!(events[i]),
          ),
      ],
    );
  }
}
