/// Cross-persona attendance sync for mock QA journeys (teacher submit → parent
/// and student KPI).
library;
import '../../../features/parent/attendance/attendance_models.dart';
import '../../attendance/attendance_sync_bridge.dart';

class MockAttendanceSyncStore {
  MockAttendanceSyncStore._();

  static final MockAttendanceSyncStore instance = MockAttendanceSyncStore._();

  /// Bumped when submission or correction state changes (Riverpod invalidation).
  static int revision = 0;

  int presentCount = 0;
  int absentCount = 0;
  int lateCount = 0;
  DateTime? lastSubmittedAt;

  bool get hasTeacherSubmission => lastSubmittedAt != null;

  /// Applied when principal approves an attendance correction (M-D4).
  int correctionDeltaPresent = 0;
  String? lastCorrectionNote;
  String? lastRejectedCorrectionNote;

  void recordCorrectionApproved({
    required int presentDelta,
    required String note,
  }) {
    presentCount += presentDelta;
    if (presentCount < 0) presentCount = 0;
    correctionDeltaPresent = presentDelta;
    lastCorrectionNote = note;
    lastRejectedCorrectionNote = null;
    revision++;
    notifyMockAttendanceSyncChanged();
  }

  void recordCorrectionRejected({required String comment}) {
    lastRejectedCorrectionNote = comment;
    revision++;
    notifyMockAttendanceSyncChanged();
  }

  void recordTeacherSubmit({
    required int present,
    required int absent,
    required int late,
  }) {
    presentCount = present;
    absentCount = absent;
    lateCount = late;
    lastSubmittedAt = DateTime.now();
    revision++;
    notifyMockAttendanceSyncChanged();
  }

  int attendancePercent({String? grade, String? section}) {
    if (!hasTeacherSubmission) return -1;
    final total = presentCount + absentCount + lateCount;
    if (total == 0) return -1;
    return ((presentCount / total) * 100).round();
  }

  /// Applies the latest teacher submission to a base month so parent AND student
  /// views reflect what the teacher actually marked. No submission → base as-is.
  AttendanceMonthData mergedMonth(AttendanceMonthData base) {
    if (!hasTeacherSubmission) return base;
    final total = presentCount + absentCount + lateCount;
    final percent = total == 0
        ? base.kpi.attendancePercent
        : ((presentCount / total) * 100).round();
    return AttendanceMonthData(
      month: base.month,
      childName: base.childName,
      childClass: base.childClass,
      kpi: AttendanceKpiMetrics(
        attendancePercent: percent,
        absentDays: absentCount,
        lateDays: lateCount,
      ),
      calendarDays: base.calendarDays,
      recentLogs: base.recentLogs,
      warningBannerMessage: base.warningBannerMessage,
      unreadNotifications: base.unreadNotifications,
      classTeacherPhone: base.classTeacherPhone,
    );
  }

  void reset() {
    presentCount = 0;
    absentCount = 0;
    lateCount = 0;
    lastSubmittedAt = null;
    correctionDeltaPresent = 0;
    lastCorrectionNote = null;
    lastRejectedCorrectionNote = null;
    revision = 0;
  }
}
