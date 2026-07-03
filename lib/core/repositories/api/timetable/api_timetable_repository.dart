import '../../interfaces/timetable_repository.dart';
import '../../repository_query.dart';
import '../../../../features/academics/timetable/timetable_models.dart';
import 'dto/timetable_dto.dart';
import 'mapper/timetable_mapper.dart';
import 'remote/timetable_remote_datasource.dart';

class ApiTimetableRepository implements TimetableRepository {
  ApiTimetableRepository({
    required TimetableRemoteDataSource remote,
    TimetableMapper mapper = const TimetableMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final TimetableRemoteDataSource _remote;
  final TimetableMapper _mapper;

  @override
  Future<TimetableSummary> getSummary({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final dto = await _remote.fetchSummary(query: query, academicYearId: academicYearId);
    return _mapper.toSummary(dto);
  }

  @override
  Future<List<TimetableEntry>> getTimetables({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final items = await _remote.fetchTimetables(query: query, academicYearId: academicYearId);
    return items.map(_mapper.toEntry).toList();
  }

  @override
  Future<TimetableDetail> getTimetable({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final data = await _remote.fetchDetail(query: query, timetableId: timetableId);
    final timetable = _mapper.toEntry(
      TimetableEntryDto.fromJson(data['timetable'] as Map<String, dynamic>? ?? const {}),
    );
    final rawPeriods = data['periods'] as List<dynamic>? ?? const [];
    final periods = rawPeriods
        .map((p) => _mapper.toPeriod(TimetablePeriodDto.fromJson(p as Map<String, dynamic>)))
        .toList();
    return TimetableDetail(timetable: timetable, periods: periods);
  }

  @override
  Future<List<TeacherWorkloadEntry>> getWorkload({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final items = await _remote.fetchWorkload(query: query, academicYearId: academicYearId);
    return items.map(_mapper.toWorkload).toList();
  }

  @override
  Future<WorkloadRollup> getWorkloadRollup({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final dto = await _remote.fetchWorkloadRollup(query: query, academicYearId: academicYearId);
    return _mapper.toWorkloadRollup(dto);
  }

  @override
  Future<TimetableConflictsBundle> getConflicts({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final data = await _remote.fetchConflicts(query: query, academicYearId: academicYearId);
    final rawConflicts = data['conflicts'] as List<dynamic>? ?? const [];
    final rawRecommendations = data['recommendations'] as List<dynamic>? ?? const [];
    return TimetableConflictsBundle(
      conflicts: rawConflicts
          .map((c) => _mapper.toConflict(TimetableConflictDto.fromJson(c as Map<String, dynamic>)))
          .toList(),
      recommendations: rawRecommendations.map((r) {
        if (r is String) return r;
        final map = r as Map<String, dynamic>;
        return map['detail'] as String? ?? map['title'] as String? ?? '';
      }).toList(),
    );
  }

  @override
  Future<List<TimetableEntry>> generate({
    required RepositoryQuery query,
    required GenerateTimetableRequest request,
  }) async {
    final items = await _remote.generate(
      query: query,
      body: {
        'academicYearId': request.academicYearId,
        if (request.sectionId != null) 'sectionId': request.sectionId,
        'periodsPerDay': request.periodsPerDay,
        'daysPerWeek': request.daysPerWeek,
      },
    );
    return items.map(_mapper.toEntry).toList();
  }

  @override
  Future<TimetableValidationResult> validate({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final dto = await _remote.validate(query: query, timetableId: timetableId);
    return _mapper.toValidation(dto);
  }

  @override
  Future<TimetableEntry> publish({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final dto = await _remote.publish(query: query, timetableId: timetableId);
    return _mapper.toEntry(dto);
  }

  @override
  Future<TimetablePeriod> movePeriod({
    required RepositoryQuery query,
    required MoveTimetablePeriodRequest request,
  }) async {
    final dto = await _remote.movePeriod(query: query, request: request);
    return _mapper.toPeriod(dto);
  }

  @override
  Future<TimetablePeriod> reassignPeriodTeacher({
    required RepositoryQuery query,
    required ReassignPeriodTeacherRequest request,
  }) async {
    final dto = await _remote.reassignPeriodTeacher(query: query, request: request);
    return _mapper.toPeriod(dto);
  }

  @override
  Future<DailySubstitutionsBundle> listSubstitutions({
    required RepositoryQuery query,
    required String date,
  }) async {
    final dto = await _remote.fetchSubstitutions(query: query, date: date);
    return _mapper.toDailyBundle(dto);
  }

  @override
  Future<TimetableSubstitution> createSubstitution({
    required RepositoryQuery query,
    required CreateSubstitutionRequest request,
  }) async {
    final dto = await _remote.createSubstitution(
      query: query,
      periodId: request.periodId,
      subDate: request.subDate,
      substituteTeacherId: request.substituteTeacherId,
      reason: request.reason,
    );
    return _mapper.toSubstitution(dto);
  }

  @override
  Future<void> deleteSubstitution({
    required RepositoryQuery query,
    required String id,
  }) async {
    await _remote.deleteSubstitution(query: query, id: id);
  }
}
