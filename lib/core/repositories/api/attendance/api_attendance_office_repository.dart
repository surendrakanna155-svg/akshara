import '../../../attendance/attendance_office_models.dart';
import '../../interfaces/attendance_office_repository.dart';
import '../../repository_query.dart';
import 'remote/attendance_office_remote_datasource.dart';

class ApiAttendanceOfficeRepository implements AttendanceOfficeRepository {
  ApiAttendanceOfficeRepository({
    required AttendanceOfficeRemoteDataSource remote,
  }) : _remote = remote;

  final AttendanceOfficeRemoteDataSource _remote;

  @override
  Future<List<AttendanceRegisterEntry>> fetchRegister({
    required RepositoryQuery query,
    required String classLabel,
    required DateTime date,
  }) =>
      _remote.fetchRegister(query: query, classLabel: classLabel, date: date);

  @override
  Future<MonthlyRegister> fetchMonthlyRegister({
    required RepositoryQuery query,
    required String classLabel,
    required String month,
  }) =>
      _remote.fetchMonthlyRegister(
        query: query,
        classLabel: classLabel,
        month: month,
      );

  @override
  Future<List<PendingAttendanceClass>> fetchPending({
    required RepositoryQuery query,
    required DateTime date,
  }) =>
      _remote.fetchPending(query: query, date: date);

  @override
  Future<List<ConsecutiveAbsenceStudent>> fetchConsecutiveAbsences({
    required RepositoryQuery query,
    int days = 3,
  }) =>
      _remote.fetchConsecutiveAbsences(query: query, days: days);

  @override
  Future<List<ShortAttendanceStudent>> fetchShortAttendance({
    required RepositoryQuery query,
    int threshold = 75,
    int windowDays = 30,
  }) =>
      _remote.fetchShortAttendance(
        query: query,
        threshold: threshold,
        windowDays: windowDays,
      );
}
