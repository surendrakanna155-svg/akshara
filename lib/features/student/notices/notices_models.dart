import 'package:flutter/foundation.dart';

enum StudentNoticeScope { all, school, classNotice }

extension StudentNoticeScopeX on StudentNoticeScope {
  String get label => switch (this) {
        StudentNoticeScope.all => 'All',
        StudentNoticeScope.school => 'School',
        StudentNoticeScope.classNotice => 'Class',
      };
}

enum StudentNoticePriority { normal, important, urgent }

extension StudentNoticePriorityX on StudentNoticePriority {
  String get label => switch (this) {
        StudentNoticePriority.normal => 'Normal',
        StudentNoticePriority.important => 'Important',
        StudentNoticePriority.urgent => 'Urgent',
      };
}

@immutable
class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.summary,
    required this.scope,
    required this.priority,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String dateLabel;
  final String summary;
  final StudentNoticeScope scope;
  final StudentNoticePriority priority;
  final bool isRead;
}

@immutable
class StudentNoticesData {
  const StudentNoticesData({
    required this.studentName,
    required this.classLabel,
    required this.notices,
    this.unreadNotifications = 0,
  });

  final String studentName;
  final String classLabel;
  final List<StudentNotice> notices;
  final int unreadNotifications;

  int get urgentCount =>
      notices.where((n) => n.priority == StudentNoticePriority.urgent).length;
  int get unreadCount => notices.where((n) => !n.isRead).length;
}
