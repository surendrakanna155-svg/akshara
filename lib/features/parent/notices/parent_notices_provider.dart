import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notices_models.dart';

/// Active notice category filter.
final parentNoticeCategoryProvider = StateProvider<NoticeCategory>(
  (ref) => NoticeCategory.all,
);

/// Reserved for API loading state.
final parentNoticesLoadingProvider = StateProvider<bool>((ref) => false);

/// Reserved for API error state.
final parentNoticesErrorProvider = StateProvider<bool>((ref) => false);

/// Toggle to emulate empty payload.
final parentNoticesEmptyProvider = StateProvider<bool>((ref) => false);

final _parentNoticesBaseProvider = Provider<List<ParentNotice>>(
  (ref) => _mockNotices(),
);

/// Filtered notices list for PA-07.
final parentNoticesItemsProvider = Provider<List<ParentNotice>>((ref) {
  if (ref.watch(parentNoticesEmptyProvider)) {
    return const [];
  }

  final filter = ref.watch(parentNoticeCategoryProvider);
  final items = ref.watch(_parentNoticesBaseProvider);

  return switch (filter) {
    NoticeCategory.all => items,
    NoticeCategory.urgent =>
      items.where((item) => item.isUrgent).toList(growable: false),
    NoticeCategory.general => items
        .where((item) => item.category == NoticeCategory.general)
        .toList(growable: false),
    NoticeCategory.academic => items
        .where((item) => item.category == NoticeCategory.academic)
        .toList(growable: false),
    NoticeCategory.transport => items
        .where((item) => item.category == NoticeCategory.transport)
        .toList(growable: false),
  };
});

/// Screen payload with filtered notices.
final parentNoticesProvider = Provider<ParentNoticesData>((ref) {
  final items = ref.watch(parentNoticesItemsProvider);

  return ParentNoticesData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    unreadNotifications: 2,
    notices: items,
  );
});

List<ParentNotice> _mockNotices() {
  return const [
    ParentNotice(
      id: 'n1',
      title: 'PTM scheduled for 15 June — please confirm your slot',
      dateLabel: '5 Jun 2026',
      summary:
          'Parent-teacher meetings will run in 15-minute slots between 2:00 PM and 6:00 PM.',
      category: NoticeCategory.academic,
      isUrgent: true,
    ),
    ParentNotice(
      id: 'n2',
      title: 'Summer vacation dates announced',
      dateLabel: '3 Jun 2026',
      summary: 'School closes from 1 Jul to 15 Jul. First day back is 16 Jul.',
      category: NoticeCategory.general,
    ),
    ParentNotice(
      id: 'n3',
      title: 'New transport route effective Monday',
      dateLabel: '1 Jun 2026',
      summary: 'Route 12 pickup time moves to 7:35 AM at Green Park stop.',
      category: NoticeCategory.transport,
    ),
    ParentNotice(
      id: 'n4',
      title: 'Annual health check-up camp on campus',
      dateLabel: '28 May 2026',
      summary: 'Consent forms must be submitted by 10 June.',
      category: NoticeCategory.general,
      isRead: true,
    ),
    ParentNotice(
      id: 'n5',
      title: 'Unit test schedule published for Term 2',
      dateLabel: '25 May 2026',
      summary: 'Mathematics and Science tests begin 12 June.',
      category: NoticeCategory.academic,
      isRead: true,
    ),
    ParentNotice(
      id: 'n6',
      title: 'Bus delay alert — Route 12 running 20 min late',
      dateLabel: '22 May 2026',
      summary: 'Traffic on Ring Road. Track live ETA in transport section.',
      category: NoticeCategory.transport,
      isUrgent: true,
      isRead: true,
    ),
  ];
}
