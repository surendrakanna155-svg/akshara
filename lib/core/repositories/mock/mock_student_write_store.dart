import '../../../features/student/homework/homework_models.dart';

/// Mutable in-memory store backing mock student write operations.
class MockStudentWriteStore {
  MockStudentWriteStore._();

  static final MockStudentWriteStore instance = MockStudentWriteStore._();

  final Map<String, StudentHomeworkItem> submittedHomework = {};
}
