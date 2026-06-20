import '../../../features/academics/timetable/timetable_models.dart';
import '../../school_config/school_configuration_models.dart';
import '../../timetable/timetable_generation_inputs.dart';
import '../../timetable/timetable_generator.dart';
import '../interfaces/timetable_repository.dart';
import '../repository_query.dart';

class MockTimetableRepository implements TimetableRepository {
  MockTimetableRepository() {
    _timetables.addAll([
      TimetableEntry(
        id: 'tt_mock_1',
        academicYearId: _yearId,
        sectionId: 'mock-section-8-A',
        status: TimetableStatus.draft,
        version: 1,
        periodsPerDay: 6,
        daysPerWeek: 5,
        updatedAt: DateTime(2026, 6, 9, 10),
      ),
      TimetableEntry(
        id: 'tt_mock_2',
        academicYearId: _yearId,
        sectionId: 'mock-section-8-B',
        status: TimetableStatus.validated,
        version: 1,
        periodsPerDay: 6,
        daysPerWeek: 5,
        updatedAt: DateTime(2026, 6, 9, 11),
      ),
    ]);
    _periods['tt_mock_1'] = _buildPeriods('tt_mock_1', includeClash: true);
    _periods['tt_mock_2'] = _buildPeriods('tt_mock_2');
  }

  static const _yearId = 'mock-year-current';

  final List<TimetableEntry> _timetables = [];
  final Map<String, List<TimetablePeriod>> _periods = {};

  List<TimetablePeriod> _buildPeriods(String timetableId, {bool includeClash = false}) {
    final periods = <TimetablePeriod>[];
    var id = 0;
    for (var day = 1; day <= 5; day++) {
      for (var period = 1; period <= 6; period++) {
        id += 1;
        periods.add(TimetablePeriod(
          id: 'period_${timetableId}_$id',
          timetableId: timetableId,
          dayOfWeek: day,
          periodNumber: period,
          subjectLabel: const [
            'Mathematics',
            'English',
            'Science',
            'Social Studies',
            'Computer Science',
            'Activity',
          ][period - 1],
          roomLabel: period <= 4 ? 'Room 201' : 'Lab 1',
          teacherId: includeClash && day == 1 && period == 1
              ? 'mock-teacher-overload'
              : 'mock-teacher-1',
        ));
      }
    }
    return periods;
  }

  @override
  Future<TimetableSummary> getSummary({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    return TimetableSummary(
      academicYearId: academicYearId,
      totalTimetables: _timetables.length,
      draftCount: _timetables.where((t) => t.status == TimetableStatus.draft).length,
      validatedCount: _timetables.where((t) => t.status == TimetableStatus.validated).length,
      publishedCount: _timetables.where((t) => t.status == TimetableStatus.published).length,
      conflictCount: 1,
      gapCount: 0,
      overloadedTeacherCount: 1,
    );
  }

  @override
  Future<List<TimetableEntry>> getTimetables({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    return List<TimetableEntry>.from(_timetables);
  }

  @override
  Future<TimetableDetail> getTimetable({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final timetable = _timetables.firstWhere((t) => t.id == timetableId);
    return TimetableDetail(
      timetable: timetable,
      periods: List<TimetablePeriod>.from(_periods[timetableId] ?? const []),
    );
  }

  @override
  Future<List<TeacherWorkloadEntry>> getWorkload({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    return const [
      TeacherWorkloadEntry(
        teacherId: 'mock-teacher-overload',
        teacherName: 'Staging Teacher A',
        periodCount: 28,
        isOverloaded: true,
      ),
      TeacherWorkloadEntry(
        teacherId: 'mock-teacher-1',
        teacherName: 'Staging Teacher B',
        periodCount: 18,
        isOverloaded: false,
      ),
    ];
  }

  @override
  Future<TimetableConflictsBundle> getConflicts({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    return const TimetableConflictsBundle(
      conflicts: [
        TimetableConflict(
          type: TimetableConflictType.teacher,
          message: 'Teacher mock-teacher-overload has overlapping assignments',
          dayOfWeek: 1,
          periodNumber: 1,
          entityId: 'mock-teacher-overload',
        ),
      ],
      recommendations: [
        'Move one period to a free slot for mock-teacher-overload (read-only suggestion).',
        'Rebalance subject teachers between sections 8-A and 8-B.',
      ],
    );
  }

  /// Real rule-based generation: builds a clash-free weekly grid for every
  /// configured section at once (so no teacher or room is double-booked across
  /// sections), reserving period 1 for each section's class teacher. The mock
  /// uses a CBSE template; the live backend supplies the school's actual
  /// curriculum and teacher-subject assignments. A roomy 8×6 grid is used so the
  /// full curriculum fits.
  @override
  Future<List<TimetableEntry>> generate({
    required RepositoryQuery query,
    required GenerateTimetableRequest request,
  }) async {
    const periodsPerDay = 8;
    const daysPerWeek = 6;
    final inputs =
        buildMockGenerationInputs(curriculum: SchoolCurriculum.cbse);
    final result = generateTimetable(
      classes: inputs.classes,
      teachers: inputs.teachers,
      periodsPerDay: periodsPerDay,
      daysPerWeek: daysPerWeek,
    );

    final generated = <TimetableEntry>[];
    final now = DateTime.now();
    for (final section in inputs.sections) {
      final sectionId = 'mock-section-${section.classLabel}';
      final existing = _timetables.indexWhere((t) => t.sectionId == sectionId);
      final id = existing >= 0
          ? _timetables[existing].id
          : 'tt_mock_${_timetables.length + generated.length + 1}';

      final entry = TimetableEntry(
        id: id,
        academicYearId: request.academicYearId,
        sectionId: sectionId,
        status: TimetableStatus.draft,
        version: existing >= 0 ? _timetables[existing].version + 1 : 1,
        periodsPerDay: periodsPerDay,
        daysPerWeek: daysPerWeek,
        updatedAt: now,
      );

      _periods[id] = [
        for (final g in result.forClass(section.classLabel))
          TimetablePeriod(
            id: 'period_${id}_${g.day}_${g.period}',
            timetableId: id,
            dayOfWeek: g.day,
            periodNumber: g.period,
            subjectLabel: g.subject,
            roomLabel: g.room ?? 'Class Room',
            teacherId: (g.teacherId == null || g.teacherId!.isEmpty)
                ? null
                : g.teacherId,
          ),
      ];

      if (existing >= 0) {
        _timetables[existing] = entry;
      } else {
        _timetables.insert(0, entry);
      }
      generated.add(entry);
    }
    return generated;
  }

  @override
  Future<TimetableValidationResult> validate({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final index = _timetables.indexWhere((t) => t.id == timetableId);
    if (index >= 0) {
      _timetables[index] = TimetableEntry(
        id: _timetables[index].id,
        academicYearId: _timetables[index].academicYearId,
        sectionId: _timetables[index].sectionId,
        status: TimetableStatus.validated,
        version: _timetables[index].version,
        periodsPerDay: _timetables[index].periodsPerDay,
        daysPerWeek: _timetables[index].daysPerWeek,
        updatedAt: DateTime.now(),
        publishedAt: _timetables[index].publishedAt,
      );
    }
    return const TimetableValidationResult(
      valid: true,
      conflictCount: 0,
      gapCount: 0,
      conflicts: [],
    );
  }

  @override
  Future<TimetableEntry> publish({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final index = _timetables.indexWhere((t) => t.id == timetableId);
    final now = DateTime.now();
    _timetables[index] = TimetableEntry(
      id: _timetables[index].id,
      academicYearId: _timetables[index].academicYearId,
      sectionId: _timetables[index].sectionId,
      status: TimetableStatus.published,
      version: _timetables[index].version,
      periodsPerDay: _timetables[index].periodsPerDay,
      daysPerWeek: _timetables[index].daysPerWeek,
      updatedAt: now,
      publishedAt: now,
    );
    return _timetables[index];
  }

  @override
  Future<TimetablePeriod> movePeriod({
    required RepositoryQuery query,
    required MoveTimetablePeriodRequest request,
  }) async {
    for (final entry in _periods.entries) {
      final index = entry.value.indexWhere((p) => p.id == request.periodId);
      if (index < 0) continue;
      final current = entry.value[index];
      final updated = TimetablePeriod(
        id: current.id,
        timetableId: current.timetableId,
        dayOfWeek: request.targetDayOfWeek,
        periodNumber: request.targetPeriodNumber,
        subjectLabel: current.subjectLabel,
        roomLabel: request.roomLabel ?? current.roomLabel,
        teacherId: current.teacherId,
      );
      entry.value[index] = updated;
      return updated;
    }
    throw StateError('Period not found');
  }

  @override
  Future<TimetablePeriod> reassignPeriodTeacher({
    required RepositoryQuery query,
    required ReassignPeriodTeacherRequest request,
  }) async {
    for (final entry in _periods.entries) {
      final index = entry.value.indexWhere((p) => p.id == request.periodId);
      if (index < 0) continue;
      final current = entry.value[index];
      final updated = TimetablePeriod(
        id: current.id,
        timetableId: current.timetableId,
        dayOfWeek: current.dayOfWeek,
        periodNumber: current.periodNumber,
        subjectLabel: current.subjectLabel,
        roomLabel: current.roomLabel,
        teacherId: request.teacherId,
      );
      entry.value[index] = updated;
      return updated;
    }
    throw StateError('Period not found');
  }
}
