import 'package:flutter/foundation.dart';

import '../dashboard/parent_dashboard_provider.dart';

/// Notice category labels for PA-07 filters.
enum NoticeCategory { all, general, academic, transport, urgent }

extension NoticeCategoryX on NoticeCategory {
  String get label {
    return switch (this) {
      NoticeCategory.all => 'All',
      NoticeCategory.general => 'General',
      NoticeCategory.academic => 'Academic',
      NoticeCategory.transport => 'Transport',
      NoticeCategory.urgent => 'Urgent',
    };
  }
}

/// Parent school notice row for PA-07.
@immutable
class ParentNotice {
  const ParentNotice({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.summary,
    required this.category,
    this.isUrgent = false,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String dateLabel;
  final String summary;
  final NoticeCategory category;
  final bool isUrgent;
  final bool isRead;

  DashboardNotice toDashboardNotice() {
    return DashboardNotice(
      id: id,
      title: title,
      dateLabel: dateLabel,
      isUrgent: isUrgent,
    );
  }
}

/// PA-07 screen payload.
@immutable
class ParentNoticesData {
  const ParentNoticesData({
    required this.childName,
    required this.childClass,
    required this.notices,
    this.unreadNotifications = 0,
  });

  final String childName;
  final String childClass;
  final List<ParentNotice> notices;
  final int unreadNotifications;

  int get totalCount => notices.length;
  int get urgentCount => notices.where((n) => n.isUrgent).length;
  int get unreadCount => notices.where((n) => !n.isRead).length;
}
