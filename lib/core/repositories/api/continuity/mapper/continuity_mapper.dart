import '../../../../../core/continuity/continuity_models.dart';
import '../dto/continuity_response_dto.dart';

class ContinuityMapper {
  const ContinuityMapper();

  ContinuityMigrationPlan toPlan(ContinuityMigrationPlanDto dto) {
    final raw = dto.raw;
    final teacher = _map(raw['teacherImpact'] as Map<String, dynamic>?);
    final timetable = _map(raw['timetableImpact'] as Map<String, dynamic>?);
    final parent = _map(raw['parentCommunicationImpact'] as Map<String, dynamic>?);
    final notification = _map(raw['notificationImpact'] as Map<String, dynamic>?);
    final assignment = _map(raw['assignmentImpact'] as Map<String, dynamic>?);
    final ownership = _map(raw['messageOwnershipImpact'] as Map<String, dynamic>?);

    return ContinuityMigrationPlan(
      id: raw['id'] as String? ?? '',
      studentId: raw['studentId'] as String? ?? '',
      fromClass: raw['fromClass'] as String? ?? '',
      fromSection: raw['fromSection'] as String? ?? '',
      toClass: raw['toClass'] as String? ?? '',
      toSection: raw['toSection'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ?? '',
      status: _status(raw['status'] as String?),
      teacherImpact: TeacherContinuityImpact(
        fromTeacherId: teacher['fromTeacherId'] as String? ?? '',
        toTeacherId: teacher['toTeacherId'] as String? ?? '',
        studentIds: _strings(teacher['studentIds']),
        threadCount: (teacher['threadCount'] as num?)?.toInt() ?? 0,
      ),
      timetableImpact: TimetableContinuityImpact(
        studentId: timetable['studentId'] as String? ?? '',
        fromSection: timetable['fromSection'] as String? ?? '',
        toSection: timetable['toSection'] as String? ?? '',
        slotIds: _strings(timetable['slotIds']),
      ),
      parentCommunicationImpact: ParentCommunicationContinuityImpact(
        studentId: parent['studentId'] as String? ?? '',
        parentIds: _strings(parent['parentIds']),
        threadIds: _strings(parent['threadIds']),
      ),
      notificationImpact: NotificationContinuityImpact(
        studentId: notification['studentId'] as String? ?? '',
        notificationIds: _strings(notification['notificationIds']),
        recipientIds: _strings(notification['recipientIds']),
      ),
      assignmentImpact: AssignmentContinuityImpact(
        studentId: assignment['studentId'] as String? ?? '',
        assignmentIds: _strings(assignment['assignmentIds']),
        migratedCount: (assignment['migratedCount'] as num?)?.toInt() ?? 0,
      ),
      messageOwnershipImpact: MessageOwnershipContinuityImpact(
        fromTeacherId: ownership['fromTeacherId'] as String? ?? '',
        toTeacherId: ownership['toTeacherId'] as String? ?? '',
        transferredThreadIds: _strings(ownership['transferredThreadIds']),
      ),
      createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ContinuityMigrationResult toResult(ContinuityMigrationResultDto dto) {
    final raw = dto.raw;
    final areas = _strings(raw['migratedAreas'])
        .map(_area)
        .toList(growable: false);
    return ContinuityMigrationResult(
      migrationId: raw['migrationId'] as String? ?? '',
      planId: raw['planId'] as String? ?? '',
      status: _status(raw['status'] as String?),
      migratedAreas: areas,
      executedAt: DateTime.tryParse(raw['executedAt'] as String? ?? '') ?? DateTime.now(),
      auditTrail: [],
    );
  }

  List<ContinuityAuditEvent> toAuditEvents(ContinuityAuditTrailDto dto) {
    return [
      for (final row in dto.items)
        ContinuityAuditEvent(
          id: row['id'] as String? ?? '',
          migrationId: row['migrationId'] as String? ?? '',
          area: _area(row['area'] as String?),
          action: row['action'] as String? ?? '',
          timestamp: DateTime.tryParse(row['timestamp'] as String? ?? '') ?? DateTime.now(),
          metadata: {
            for (final entry in (row['metadata'] as Map<String, dynamic>? ?? const {}).entries)
              entry.key: '${entry.value}',
          },
        ),
    ];
  }

  Map<String, dynamic> _map(Map<String, dynamic>? value) => value ?? const {};

  List<String> _strings(Object? value) {
    return (value as List<dynamic>? ?? const []).map((e) => '$e').toList(growable: false);
  }

  ContinuityPlanStatus _status(String? value) {
    return switch (value) {
      'previewed' => ContinuityPlanStatus.previewed,
      'executed' => ContinuityPlanStatus.executed,
      'failed' => ContinuityPlanStatus.failed,
      _ => ContinuityPlanStatus.draft,
    };
  }

  ContinuityMigrationArea _area(String? value) {
    return switch (value) {
      'teacher' => ContinuityMigrationArea.teacher,
      'timetable' => ContinuityMigrationArea.timetable,
      'parentCommunication' => ContinuityMigrationArea.parentCommunication,
      'notification' => ContinuityMigrationArea.notification,
      'assignment' => ContinuityMigrationArea.assignment,
      'messageOwnership' => ContinuityMigrationArea.messageOwnership,
      _ => ContinuityMigrationArea.teacher,
    };
  }
}
