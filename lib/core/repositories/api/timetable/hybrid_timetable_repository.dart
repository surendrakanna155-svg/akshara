import '../../interfaces/timetable_repository.dart';
import '../../repository_query.dart';
import '../../../../features/academic/timetable/timetable_models.dart';
import 'api_timetable_repository.dart';

class HybridTimetableRepository implements TimetableRepository {
  HybridTimetableRepository({required ApiTimetableRepository api}) : _api = api;

  final ApiTimetableRepository _api;

  @override
  Future<TimetableSummary> getSummary({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.getSummary(query: query, academicYearId: academicYearId);

  @override
  Future<List<TimetableEntry>> getTimetables({
    required RepositoryQuery query,
    String? academicYearId,
  }) =>
      _api.getTimetables(query: query, academicYearId: academicYearId);

  @override
  Future<TimetableDetail> getTimetable({
    required RepositoryQuery query,
    required String timetableId,
  }) =>
      _api.getTimetable(query: query, timetableId: timetableId);

  @override
  Future<List<TeacherWorkloadEntry>> getWorkload({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.getWorkload(query: query, academicYearId: academicYearId);

  @override
  Future<TimetableConflictsBundle> getConflicts({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.getConflicts(query: query, academicYearId: academicYearId);

  @override
  Future<List<TimetableEntry>> generate({
    required RepositoryQuery query,
    required GenerateTimetableRequest request,
  }) =>
      _api.generate(query: query, request: request);

  @override
  Future<TimetableValidationResult> validate({
    required RepositoryQuery query,
    required String timetableId,
  }) =>
      _api.validate(query: query, timetableId: timetableId);

  @override
  Future<TimetableEntry> publish({
    required RepositoryQuery query,
    required String timetableId,
  }) =>
      _api.publish(query: query, timetableId: timetableId);

  @override
  Future<TimetablePeriod> movePeriod({
    required RepositoryQuery query,
    required MoveTimetablePeriodRequest request,
  }) =>
      _api.movePeriod(query: query, request: request);
}
