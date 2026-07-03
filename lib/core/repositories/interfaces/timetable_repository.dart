import '../../../features/academics/timetable/timetable_models.dart';
import '../repository_query.dart';

abstract class TimetableRepository {
  Future<TimetableSummary> getSummary({
    required RepositoryQuery query,
    required String academicYearId,
  });

  Future<List<TimetableEntry>> getTimetables({
    required RepositoryQuery query,
    String? academicYearId,
  });

  Future<TimetableDetail> getTimetable({
    required RepositoryQuery query,
    required String timetableId,
  });

  Future<List<TeacherWorkloadEntry>> getWorkload({
    required RepositoryQuery query,
    required String academicYearId,
  });

  Future<TimetableConflictsBundle> getConflicts({
    required RepositoryQuery query,
    required String academicYearId,
  });

  Future<List<TimetableEntry>> generate({
    required RepositoryQuery query,
    required GenerateTimetableRequest request,
  });

  Future<TimetableValidationResult> validate({
    required RepositoryQuery query,
    required String timetableId,
  });

  Future<TimetableEntry> publish({
    required RepositoryQuery query,
    required String timetableId,
  });

  Future<TimetablePeriod> movePeriod({
    required RepositoryQuery query,
    required MoveTimetablePeriodRequest request,
  });

  Future<TimetablePeriod> reassignPeriodTeacher({
    required RepositoryQuery query,
    required ReassignPeriodTeacherRequest request,
  });

  /// Resolved substitutions for [date] (YYYY-MM-DD) plus the server-derived
  /// on-leave teachers for that day.
  Future<DailySubstitutionsBundle> listSubstitutions({
    required RepositoryQuery query,
    required String date,
  });

  /// Create (or idempotently re-assign) a dated cover. Throws
  /// [SubstituteBusyException] when the substitute already teaches that slot.
  Future<TimetableSubstitution> createSubstitution({
    required RepositoryQuery query,
    required CreateSubstitutionRequest request,
  });

  /// Remove a substitution by id.
  Future<void> deleteSubstitution({
    required RepositoryQuery query,
    required String id,
  });
}
