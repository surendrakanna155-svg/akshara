import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notices_models.dart';

final studentNoticeScopeProvider = StateProvider<StudentNoticeScope>(
  (ref) => StudentNoticeScope.all,
);

final studentNoticesLoadingProvider = StateProvider<bool>((ref) => false);
final studentNoticesErrorProvider = StateProvider<bool>((ref) => false);
final studentNoticesEmptyProvider = StateProvider<bool>((ref) => false);

final _studentNoticesBaseProvider = Provider<List<StudentNotice>>(
  (ref) => _mockNotices(),
);

final studentNoticesItemsProvider = Provider<List<StudentNotice>>((ref) {
  if (ref.watch(studentNoticesEmptyProvider)) return const [];

  final scope = ref.watch(studentNoticeScopeProvider);
  final items = ref.watch(_studentNoticesBaseProvider);

  return switch (scope) {
    StudentNoticeScope.all => items,
    StudentNoticeScope.school => items
        .where((n) => n.scope == StudentNoticeScope.school)
        .toList(growable: false),
    StudentNoticeScope.classNotice => items
        .where((n) => n.scope == StudentNoticeScope.classNotice)
        .toList(growable: false),
  };
});

final studentNoticesProvider = Provider<StudentNoticesData>((ref) {
  return StudentNoticesData(
    studentName: 'Ravi Kumar',
    classLabel: '8-A',
    unreadNotifications: 2,
    notices: ref.watch(studentNoticesItemsProvider),
  );
});

List<StudentNotice> _mockNotices() {
  return const [
    StudentNotice(
      id: 'sn-1',
      title: 'School closed on 15 June for staff training',
      dateLabel: '5 Jun 2026',
      summary: 'Regular classes resume on 16 June. Online resources will be shared.',
      scope: StudentNoticeScope.school,
      priority: StudentNoticePriority.urgent,
    ),
    StudentNotice(
      id: 'sn-2',
      title: 'Class 8-A science fair project deadline',
      dateLabel: '4 Jun 2026',
      summary: 'Submit your project outline to Mrs. Rao by 10 June.',
      scope: StudentNoticeScope.classNotice,
      priority: StudentNoticePriority.important,
    ),
    StudentNotice(
      id: 'sn-3',
      title: 'Library week — extra reading hours',
      dateLabel: '3 Jun 2026',
      summary: 'Library open till 5 PM all week. Borrow up to 3 books.',
      scope: StudentNoticeScope.school,
      priority: StudentNoticePriority.normal,
      isRead: true,
    ),
    StudentNotice(
      id: 'sn-4',
      title: '8-A maths revision session Saturday',
      dateLabel: '2 Jun 2026',
      summary: 'Optional revision class 9–11 AM in Room 203.',
      scope: StudentNoticeScope.classNotice,
      priority: StudentNoticePriority.important,
    ),
  ];
}
