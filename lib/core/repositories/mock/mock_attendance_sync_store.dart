/// Cross-persona attendance sync for mock QA journeys (teacher submit → parent KPI).
class MockAttendanceSyncStore {
  MockAttendanceSyncStore._();

  static final MockAttendanceSyncStore instance = MockAttendanceSyncStore._();

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
  }

  void recordCorrectionRejected({required String comment}) {
    lastRejectedCorrectionNote = comment;
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
  }

  int attendancePercent({String? grade, String? section}) {
    if (!hasTeacherSubmission) return -1;
    final total = presentCount + absentCount + lateCount;
    if (total == 0) return -1;
    return ((presentCount / total) * 100).round();
  }

  void reset() {
    presentCount = 0;
    absentCount = 0;
    lateCount = 0;
    lastSubmittedAt = null;
    correctionDeltaPresent = 0;
    lastCorrectionNote = null;
    lastRejectedCorrectionNote = null;
  }
}
