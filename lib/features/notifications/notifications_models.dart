import 'package:flutter/material.dart';

import '../admin/models/admin_nav_models.dart';

/// Notification categories per [Notifications.md] §5.
enum NotificationCategory {
  fee,
  attendance,
  academic,
  transport,
  hostel,
  approval,
  announcement,
  system,
}

extension NotificationCategoryX on NotificationCategory {
  IconData get icon => switch (this) {
        NotificationCategory.fee => Icons.payments_outlined,
        NotificationCategory.attendance => Icons.fact_check_outlined,
        NotificationCategory.academic => Icons.school_outlined,
        NotificationCategory.transport => Icons.directions_bus_outlined,
        NotificationCategory.hostel => Icons.night_shelter_outlined,
        NotificationCategory.approval => Icons.task_alt_outlined,
        NotificationCategory.announcement => Icons.campaign_outlined,
        NotificationCategory.system => Icons.info_outline,
      };

  String get label => switch (this) {
        NotificationCategory.fee => 'Fees',
        NotificationCategory.attendance => 'Attendance',
        NotificationCategory.academic => 'Academic',
        NotificationCategory.transport => 'Transport',
        NotificationCategory.hostel => 'Hostel',
        NotificationCategory.approval => 'Approval',
        NotificationCategory.announcement => 'Announcement',
        NotificationCategory.system => 'System',
      };

  /// Owning optional [AdminModule] for dynamic-config capability gating, or null
  /// for core categories that are always visible. Only optional-module
  /// categories map to a module so an inbox can hide notifications for a module
  /// the school has turned off (gap G7) — reusing the same capability mapping
  /// the admin nav uses ([SchoolCapabilityRegistry.isAdminModuleEnabled]).
  AdminModule? get capabilityModule => switch (this) {
        NotificationCategory.transport => AdminModule.transport,
        NotificationCategory.hostel => AdminModule.hostel,
        NotificationCategory.fee ||
        NotificationCategory.attendance ||
        NotificationCategory.academic ||
        NotificationCategory.approval ||
        NotificationCategory.announcement ||
        NotificationCategory.system =>
          null,
      };
}

/// Inbox filter chips for NT-01 mobile pattern.
enum NotificationFilter {
  all,
  unread,
  fees,
  attendance,
  academic,
}

extension NotificationFilterX on NotificationFilter {
  String get label => switch (this) {
        NotificationFilter.all => 'All',
        NotificationFilter.unread => 'Unread',
        NotificationFilter.fees => 'Fees',
        NotificationFilter.attendance => 'Attendance',
        NotificationFilter.academic => 'Academic',
      };
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.category,
    this.isRead = false,
    this.isArchived = false,
    this.isUrgent = false,
    this.childContext,
    this.requiresAck = false,
    this.acknowledgedAt,
  });

  final String id;
  final String title;
  final String preview;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;
  final bool isArchived;
  final bool isUrgent;

  /// Shown as chip when parent has multiple children (NT mobile spec).
  final String? childContext;

  /// COM-D1: this delivery requires the recipient to acknowledge it.
  final bool requiresAck;

  /// COM-D1: when the recipient acknowledged it (null = not yet acknowledged).
  final DateTime? acknowledgedAt;

  /// COM-D1: an acknowledgement is still outstanding.
  bool get needsAcknowledgement => requiresAck && acknowledgedAt == null;

  AppNotification copyWith({
    bool? isRead,
    bool? isArchived,
    DateTime? acknowledgedAt,
  }) {
    return AppNotification(
      id: id,
      title: title,
      preview: preview,
      timestamp: timestamp,
      category: category,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      isUrgent: isUrgent,
      childContext: childContext,
      requiresAck: requiresAck,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }
}
