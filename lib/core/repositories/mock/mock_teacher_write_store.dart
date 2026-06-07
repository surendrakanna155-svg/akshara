import '../../../features/teacher/attendance/attendance_models.dart';
import '../../../features/teacher/exams/exam_models.dart';
import '../../../features/teacher/homework/homework_models.dart';
import '../../../features/teacher/leave/leave_models.dart';
import '../../../features/teacher/messages/message_models.dart';

/// Mutable in-memory store backing mock teacher write operations.
class MockTeacherWriteStore {
  MockTeacherWriteStore._();

  static final MockTeacherWriteStore instance = MockTeacherWriteStore._();

  final Map<String, Map<String, StudentAttendanceMark>> attendanceDrafts = {};
  final Set<String> submittedClasses = {};
  final Map<String, HomeworkSubmission> reviewedSubmissions = {};
  final Map<String, ExamMarkEntry> updatedMarks = {};
  List<TeacherLeaveRequest>? leaveRequests;
  List<MessageThread>? messageThreads;

  int _leaveSeq = 100;
  int _threadSeq = 200;
  int _messageSeq = 300;

  String nextLeaveId() => 'tlv_${++_leaveSeq}';
  String nextThreadId() => 'thread_${++_threadSeq}';
  String nextMessageId() => 'msg_${++_messageSeq}';
}
