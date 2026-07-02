import '../../core/communication/parent_communication_models.dart';
import '../../core/communication/teacher_parent_templates.dart';
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
    this.halfDayCount = 0,
    this.excusedCount = 0,
  });

  final String classId;
  final String submittedAtLabel;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int halfDayCount;
  final int excusedCount;
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

/// Domain request to publish processed exam results to student/parent apps.
class TeacherExamPublishRequest {
  const TeacherExamPublishRequest({required this.examId});

  final String examId;
}

/// Result of publishing exam results.
class TeacherExamPublishResult {
  const TeacherExamPublishResult({
    required this.examId,
    required this.examTitle,
    required this.publishedCount,
    required this.publishedAtLabel,
  });

  final String examId;
  final String examTitle;
  final int publishedCount;
  final String publishedAtLabel;
}

/// Domain request to submit exam results for principal approval (M-D3).
class TeacherExamSubmitApprovalRequest {
  const TeacherExamSubmitApprovalRequest({required this.examId});

  final String examId;
}

/// Result of submitting exam results for approval.
class TeacherExamSubmitApprovalResult {
  const TeacherExamSubmitApprovalResult({
    required this.examId,
    required this.approvalId,
    required this.title,
    required this.statusLabel,
  });

  final String examId;
  final String approvalId;
  final String title;
  final String statusLabel;
}

/// Domain request to process exam marks for coordinator verification (M-A5).
class TeacherExamProcessResultsRequest {
  const TeacherExamProcessResultsRequest({required this.examId});

  final String examId;
}

/// Result of processing exam marks for verification.
class TeacherExamProcessResultsResult {
  const TeacherExamProcessResultsResult({
    required this.examId,
    required this.examTitle,
    required this.phaseLabel,
  });

  final String examId;
  final String examTitle;
  final String phaseLabel;
}

/// Domain request to send structured parent communication.
class TeacherParentCommunicationSendRequest {
  const TeacherParentCommunicationSendRequest({
    required this.sisStudentId,
    required this.reason,
    required this.tone,
    required this.channels,
    this.customMessage,
    this.useAi = false,
    this.sourceConcernId,
  });

  final String sisStudentId;
  final ParentCommunicationReason reason;
  final ParentCommunicationTone tone;
  final Set<ParentCommunicationChannel> channels;
  final String? customMessage;
  final bool useAi;
  final String? sourceConcernId;
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

/// Domain request to create a homework assignment.
class TeacherHomeworkCreateRequest {
  const TeacherHomeworkCreateRequest({
    required this.classLabel,
    required this.subject,
    required this.title,
    required this.dueDate,
    this.dueLabel = '',
    this.studentName,
  });

  final String classLabel;
  final String subject;
  final String title;

  /// HWK-1 — the real machine-readable due date in ISO `YYYY-MM-DD` form,
  /// chosen via a date picker. Required on the pilot create path; the backend
  /// rejects a blank/invalid value with 422.
  final String dueDate;

  /// Optional human label ("Due 08 Jul"). When blank the backend derives it
  /// from [dueDate] so existing renderers keep working.
  final String dueLabel;

  /// Optional. Null/empty = delivered to the whole class.
  final String? studentName;
}

/// Subject teacher escalates concern to class teacher (no direct parent send).
class TeacherSubjectConcernFlagRequest {
  const TeacherSubjectConcernFlagRequest({
    required this.sisStudentId,
    required this.category,
    required this.observation,
  });

  final String sisStudentId;
  final SubjectConcernCategory category;
  final String observation;
}

/// Request to correct attendance after class submission (Phase B).
class TeacherAttendanceCorrectionRequest {
  const TeacherAttendanceCorrectionRequest({
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.section,
    required this.dateLabel,
    required this.fromMark,
    required this.toMark,
    required this.reason,
    this.presentDelta = 1,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String section;
  final String dateLabel;
  final String fromMark;
  final String toMark;
  final String reason;
  final int presentDelta;
}

class TeacherAttendanceCorrectionResult {
  const TeacherAttendanceCorrectionResult({
    required this.correctionId,
    required this.approvalId,
  });

  final String correctionId;
  final String approvalId;
}
