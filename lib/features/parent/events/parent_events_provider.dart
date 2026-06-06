import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'events_models.dart';

/// Active events section tab.
final parentEventSectionProvider = StateProvider<EventSection>(
  (ref) => EventSection.upcoming,
);

/// Reserved for API loading state.
final parentEventsLoadingProvider = StateProvider<bool>((ref) => false);

/// Reserved for API error state.
final parentEventsErrorProvider = StateProvider<bool>((ref) => false);

/// Toggle to emulate empty payload.
final parentEventsEmptyProvider = StateProvider<bool>((ref) => false);

final parentEventsProvider = Provider<ParentEventsData>((ref) {
  if (ref.watch(parentEventsEmptyProvider)) {
    return const ParentEventsData(
      childName: 'Ravi Kumar',
      childClass: '8-A',
      unreadNotifications: 2,
      upcomingEvents: [],
      pastEvents: [],
    );
  }

  return const ParentEventsData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    unreadNotifications: 2,
    upcomingEvents: [
      ParentEvent(
        id: 'e1',
        day: 12,
        month: 'Jun',
        title: 'Science Exhibition',
        timeLabel: '9:00 AM',
        venueLabel: 'Main Hall',
        subtitle: '9:00 AM · Main Hall',
        isRsvpOpen: true,
      ),
      ParentEvent(
        id: 'e2',
        day: 18,
        month: 'Jun',
        title: 'Parent-Teacher Meeting',
        timeLabel: '2:00 PM',
        venueLabel: 'Block B',
        subtitle: '2:00 PM · Block B',
        isRsvpOpen: true,
      ),
      ParentEvent(
        id: 'e3',
        day: 25,
        month: 'Jun',
        title: 'Annual Sports Day',
        timeLabel: '8:00 AM',
        venueLabel: 'Sports Ground',
        subtitle: '8:00 AM · Sports Ground',
      ),
      ParentEvent(
        id: 'e4',
        day: 8,
        month: 'Jul',
        title: 'Inter-house Debate Finals',
        timeLabel: '11:00 AM',
        venueLabel: 'Auditorium',
        subtitle: '11:00 AM · Auditorium',
      ),
    ],
    pastEvents: [
      ParentEvent(
        id: 'e5',
        day: 20,
        month: 'May',
        title: 'Founders Day Assembly',
        timeLabel: '10:00 AM',
        venueLabel: 'Main Hall',
        subtitle: '10:00 AM · Main Hall',
        isPast: true,
      ),
      ParentEvent(
        id: 'e6',
        day: 5,
        month: 'May',
        title: 'Earth Day Plantation Drive',
        timeLabel: '7:30 AM',
        venueLabel: 'School Garden',
        subtitle: '7:30 AM · School Garden',
        isPast: true,
      ),
    ],
  );
});
