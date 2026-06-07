import '../../../../features/parent/attendance/attendance_models.dart';
import '../../../../features/parent/timetable/timetable_models.dart';
import '../../../../features/student/dashboard/student_dashboard_provider.dart';
import '../../../../features/student/exams/exam_models.dart';
import '../../../../features/student/homework/homework_models.dart';
import '../../../../features/student/notices/notices_models.dart';
import '../../../../features/student/profile/profile_models.dart';
import '../../interfaces/student_repository.dart';
import '../../repository_query.dart';
import 'mapper/student_mapper.dart';
import 'remote/student_remote_datasource.dart';

/// API implementation of [StudentRepository] — enabled via [studentApiEnabledProvider].
class ApiStudentRepository implements StudentRepository {
  ApiStudentRepository({
    required StudentRemoteDataSource remote,
    StudentMapper mapper = const StudentMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final StudentRemoteDataSource _remote;
  final StudentMapper _mapper;

  @override
  Future<StudentDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async {
    final dto = await _remote.fetchAttendance(query: query, month: month);
    return _mapper.toAttendance(dto);
  }

  @override
  Future<List<StudentHomeworkItem>> getHomeworkItems({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchHomeworkItems(query: query);
    return _mapper.toHomeworkItems(dto);
  }

  @override
  Future<StudentExamsData> getExams({required RepositoryQuery query}) async {
    final dto = await _remote.fetchExams(query: query);
    return _mapper.toExams(dto);
  }

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async {
    final dto = await _remote.fetchTimetable(query: query);
    return _mapper.toTimetable(dto);
  }

  @override
  Future<List<StudentNotice>> getNotices({required RepositoryQuery query}) async {
    final dto = await _remote.fetchNotices(query: query);
    return _mapper.toNotices(dto);
  }

  @override
  Future<StudentProfileData> getProfile({required RepositoryQuery query}) async {
    final dto = await _remote.fetchProfile(query: query);
    return _mapper.toProfile(dto);
  }
}
