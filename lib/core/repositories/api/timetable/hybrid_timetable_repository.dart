import '../../interfaces/timetable_repository.dart';
import '../../repository_query.dart';
import '../../../../features/academics/timetable/timetable_models.dart';
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
  Future<WorkloadRollup> getWorkloadRollup({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.getWorkloadRollup(query: query, academicYearId: academicYearId);

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

  @override
  Future<TimetablePeriod> reassignPeriodTeacher({
    required RepositoryQuery query,
    required ReassignPeriodTeacherRequest request,
  }) =>
      _api.reassignPeriodTeacher(query: query, request: request);

  @override
  Future<DailySubstitutionsBundle> listSubstitutions({
    required RepositoryQuery query,
    required String date,
  }) =>
      _api.listSubstitutions(query: query, date: date);

  @override
  Future<TimetableSubstitution> createSubstitution({
    required RepositoryQuery query,
    required CreateSubstitutionRequest request,
  }) =>
      _api.createSubstitution(query: query, request: request);

  @override
  Future<void> deleteSubstitution({
    required RepositoryQuery query,
    required String id,
  }) =>
      _api.deleteSubstitution(query: query, id: id);
}
