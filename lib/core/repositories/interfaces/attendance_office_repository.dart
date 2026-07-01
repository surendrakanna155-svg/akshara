import '../../attendance/attendance_office_models.dart';
import '../repository_query.dart';

/// OFFICE / ADMIN student-attendance reads (ATT-1, ATT-2, ATT-4, ATT-D1, ATT-D2).
/// Read-only; there is no write method on this repository.
abstract class AttendanceOfficeRepository {
  /// ATT-1 — per-student register for a class on a specific date.
  Future<List<AttendanceRegisterEntry>> fetchRegister({
    required RepositoryQuery query,
    required String classLabel,
    required DateTime date,
  });

  /// ATT-2 — students×days matrix for a class in a month.
  Future<MonthlyRegister> fetchMonthlyRegister({
    required RepositoryQuery query,
    required String classLabel,
    required String month, // YYYY-MM
  });

  /// ATT-4 — classes with no submitted session for the date.
  Future<List<PendingAttendanceClass>> fetchPending({
    required RepositoryQuery query,
    required DateTime date,
  });

  /// ATT-D1 — students absent on the last [days] consecutive marked school days.
  Future<List<ConsecutiveAbsenceStudent>> fetchConsecutiveAbsences({
    required RepositoryQuery query,
    int days = 3,
  });

  /// ATT-D2 — students whose attendance % (over [windowDays]) is below [threshold].
  Future<List<ShortAttendanceStudent>> fetchShortAttendance({
    required RepositoryQuery query,
    int threshold = 75,
    int windowDays = 30,
  });
}
