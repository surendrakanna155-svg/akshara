import 'package:flutter/foundation.dart';

import '../dashboard/parent_dashboard_provider.dart';

/// Event list sections for PA-08.
enum EventSection { upcoming, past }

extension EventSectionX on EventSection {
  String get label {
    return switch (this) {
      EventSection.upcoming => 'Upcoming',
      EventSection.past => 'Past',
    };
  }
}

/// Parent school event row for PA-08.
@immutable
class ParentEvent {
  const ParentEvent({
    required this.id,
    required this.day,
    required this.month,
    required this.title,
    required this.timeLabel,
    required this.venueLabel,
    this.subtitle,
    this.isRsvpOpen = false,
    this.isPast = false,
  });

  final String id;
  final int day;
  final String month;
  final String title;
  final String timeLabel;
  final String venueLabel;
  final String? subtitle;
  final bool isRsvpOpen;
  final bool isPast;

  DashboardEvent toDashboardEvent() {
    return DashboardEvent(
      id: id,
      day: day,
      month: month,
      title: title,
      subtitle: subtitle ?? '$timeLabel · $venueLabel',
    );
  }
}

/// PA-08 screen payload.
@immutable
class ParentEventsData {
  const ParentEventsData({
    required this.childName,
    required this.childClass,
    required this.upcomingEvents,
    required this.pastEvents,
    this.unreadNotifications = 0,
  });

  final String childName;
  final String childClass;
  final List<ParentEvent> upcomingEvents;
  final List<ParentEvent> pastEvents;
  final int unreadNotifications;

  int get upcomingCount => upcomingEvents.length;
  int get pastCount => pastEvents.length;
}
