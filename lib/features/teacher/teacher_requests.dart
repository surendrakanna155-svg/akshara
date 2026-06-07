import 'attendance/attendance_models.dart';
import 'homework/homework_models.dart';

/// Single student attendance mark in a draft or submit payload.
class TeacherAttendanceMarkEntry {
  const TeacherAttendanceMarkEntry({
    required this.studentId,
    required this.mark,
  });

  final String studentId;
  final StudentAttendanceMark mark;
}

/// Domain request to save attendance marks as a draft.
class TeacherAttendanceDraftRequest {
  const TeacherAttendanceDraftRequest({
    required this.classId,
    required this.entries,
  });

  final String classId;
  final List<TeacherAttendanceMarkEntry> entries;
}

/// Result of saving an attendance draft.
class TeacherAttendanceDraftResult {
  const TeacherAttendanceDraftResult({
    required this.classId,
    required this.savedAtLabel,
    required this.markedCount,
  });

  final String classId;
  final String savedAtLabel;
  final int markedCount;
}

/// Domain request to submit final class attendance.
class TeacherAttendanceSubmitRequest {
  const TeacherAttendanceSubmitRequest({
    required this.classId,
    required this.entries,
  });

  final String classId;
  final List<TeacherAttendanceMarkEntry> entries;
}

/// Result of submitting class attendance.
class TeacherAttendanceSubmitResult {
  const TeacherAttendanceSubmitResult({
    required this.classId,
    required this.submittedAtLabel,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
  });

  final String classId;
  final String submittedAtLabel;
  final int presentCount;
  final int absentCount;
  final int lateCount;
}

/// Domain request to review a homework submission.
class TeacherHomeworkReviewRequest {
  const TeacherHomeworkReviewRequest({
    required this.submissionId,
    required this.grade,
    this.comment = '',
  });

  final String submissionId;
  final String grade;
  final String comment;
}

/// Result of reviewing a homework submission.
class TeacherHomeworkReviewResult {
  const TeacherHomeworkReviewResult({required this.submission});

  final HomeworkSubmission submission;
}

/// Domain request to update an exam mark entry.
class TeacherExamMarkUpdateRequest {
  const TeacherExamMarkUpdateRequest({
    required this.markEntryId,
    required this.marksObtained,
  });

  final String markEntryId;
  final int marksObtained;
}

/// Domain request to submit a teacher leave application.
class TeacherLeaveSubmitRequest {
  const TeacherLeaveSubmitRequest({
    required this.typeLabel,
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.reason,
  });

  final String typeLabel;
  final String fromDateLabel;
  final String toDateLabel;
  final String reason;
}

/// Domain request to send a message to a parent.
class TeacherMessageSendRequest {
  const TeacherMessageSendRequest({
    required this.recipient,
    required this.subject,
    required this.body,
    this.threadId,
  });

  final String recipient;
  final String subject;
  final String body;
  final String? threadId;
}
