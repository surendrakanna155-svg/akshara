import 'package:flutter/foundation.dart';

enum ContinuityPlanStatus { draft, previewed, executed, failed }

enum ContinuityMigrationArea {
  teacher,
  timetable,
  parentCommunication,
  notification,
  assignment,
  messageOwnership,
}

@immutable
class TeacherContinuityImpact {
  const TeacherContinuityImpact({
    required this.fromTeacherId,
    required this.toTeacherId,
    required this.studentIds,
    required this.threadCount,
  });

  final String fromTeacherId;
  final String toTeacherId;
  final List<String> studentIds;
  final int threadCount;
}

@immutable
class TimetableContinuityImpact {
  const TimetableContinuityImpact({
    required this.studentId,
    required this.fromSection,
    required this.toSection,
    required this.slotIds,
  });

  final String studentId;
  final String fromSection;
  final String toSection;
  final List<String> slotIds;
}

@immutable
class ParentCommunicationContinuityImpact {
  const ParentCommunicationContinuityImpact({
    required this.studentId,
    required this.parentIds,
    required this.threadIds,
  });

  final String studentId;
  final List<String> parentIds;
  final List<String> threadIds;
}

@immutable
class NotificationContinuityImpact {
  const NotificationContinuityImpact({
    required this.studentId,
    required this.notificationIds,
    required this.recipientIds,
  });

  final String studentId;
  final List<String> notificationIds;
  final List<String> recipientIds;
}

@immutable
class AssignmentContinuityImpact {
  const AssignmentContinuityImpact({
    required this.studentId,
    required this.assignmentIds,
    required this.migratedCount,
  });

  final String studentId;
  final List<String> assignmentIds;
  final int migratedCount;
}

@immutable
class MessageOwnershipContinuityImpact {
  const MessageOwnershipContinuityImpact({
    required this.fromTeacherId,
    required this.toTeacherId,
    required this.transferredThreadIds,
  });

  final String fromTeacherId;
  final String toTeacherId;
  final List<String> transferredThreadIds;
}

@immutable
class ContinuityAuditEvent {
  const ContinuityAuditEvent({
    required this.id,
    required this.migrationId,
    required this.area,
    required this.action,
    required this.timestamp,
    required this.metadata,
  });

  final String id;
  final String migrationId;
  final ContinuityMigrationArea area;
  final String action;
  final DateTime timestamp;
  final Map<String, String> metadata;
}

@immutable
class ContinuityMigrationPlan {
  const ContinuityMigrationPlan({
    required this.id,
    required this.studentId,
    required this.fromClass,
    required this.fromSection,
    required this.toClass,
    required this.toSection,
    required this.academicYear,
    required this.status,
    required this.teacherImpact,
    required this.timetableImpact,
    required this.parentCommunicationImpact,
    required this.notificationImpact,
    required this.assignmentImpact,
    required this.messageOwnershipImpact,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String fromClass;
  final String fromSection;
  final String toClass;
  final String toSection;
  final String academicYear;
  final ContinuityPlanStatus status;
  final TeacherContinuityImpact teacherImpact;
  final TimetableContinuityImpact timetableImpact;
  final ParentCommunicationContinuityImpact parentCommunicationImpact;
  final NotificationContinuityImpact notificationImpact;
  final AssignmentContinuityImpact assignmentImpact;
  final MessageOwnershipContinuityImpact messageOwnershipImpact;
  final DateTime createdAt;
}

@immutable
class ContinuityMigrationResult {
  const ContinuityMigrationResult({
    required this.migrationId,
    required this.planId,
    required this.status,
    required this.migratedAreas,
    required this.executedAt,
    required this.auditTrail,
  });

  final String migrationId;
  final String planId;
  final ContinuityPlanStatus status;
  final List<ContinuityMigrationArea> migratedAreas;
  final DateTime executedAt;
  final List<ContinuityAuditEvent> auditTrail;
}
