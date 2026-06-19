import '../../features/parent/notices/notices_models.dart';
import '../../features/student/notices/notices_models.dart';

class _Broadcast {
  const _Broadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
}

/// Broadcasts the school sends, surfaced to the right audience's notices so a
/// sent announcement actually reaches parents and/or students.
class SchoolBroadcastStore {
  SchoolBroadcastStore._();
  static final SchoolBroadcastStore instance = SchoolBroadcastStore._();

  final List<_Broadcast> _items = []; // newest first
  int _seq = 0;

  String add({
    required String title,
    required String body,
    required String audience,
  }) {
    _seq++;
    final id = 'bcast_$_seq';
    _items.insert(
      0,
      _Broadcast(id: id, title: title, body: body, audience: audience),
    );
    return id;
  }

  bool _toParents(String a) => a == 'all' || a.toLowerCase().contains('parent');
  bool _toStudents(String a) =>
      a == 'all' || a.toLowerCase().contains('student');

  List<ParentNotice> parentNotices() => [
        for (final b in _items)
          if (_toParents(b.audience))
            ParentNotice(
              id: b.id,
              title: b.title,
              dateLabel: 'Just now',
              summary: b.body,
              category: NoticeCategory.general,
            ),
      ];

  List<StudentNotice> studentNotices() => [
        for (final b in _items)
          if (_toStudents(b.audience))
            StudentNotice(
              id: b.id,
              title: b.title,
              dateLabel: 'Just now',
              summary: b.body,
              scope: StudentNoticeScope.school,
              priority: StudentNoticePriority.normal,
            ),
      ];

  void reset() {
    _items.clear();
    _seq = 0;
  }
}
