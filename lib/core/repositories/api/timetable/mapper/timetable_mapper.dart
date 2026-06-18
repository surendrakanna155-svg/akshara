import '../../../../../features/academics/timetable/timetable_models.dart';
import '../dto/timetable_dto.dart';

class TimetableMapper {
  const TimetableMapper();

  TimetableSummary toSummary(TimetableSummaryDto dto) {
    return TimetableSummary(
      academicYearId: dto.academicYearId,
      totalTimetables: dto.totalTimetables,
      draftCount: dto.draftCount,
      validatedCount: dto.validatedCount,
      publishedCount: dto.publishedCount,
      conflictCount: dto.conflictCount,
      gapCount: dto.gapCount,
      overloadedTeacherCount: dto.overloadedTeacherCount,
    );
  }

  TimetableEntry toEntry(TimetableEntryDto dto) {
    return TimetableEntry(
      id: dto.id,
      academicYearId: dto.academicYearId,
      sectionId: dto.sectionId,
      status: TimetableStatusApi.fromApi(dto.status) ?? TimetableStatus.draft,
      version: dto.version,
      periodsPerDay: dto.periodsPerDay,
      daysPerWeek: dto.daysPerWeek,
      updatedAt: DateTime.parse(dto.updatedAt),
      publishedAt: dto.publishedAt == null ? null : DateTime.parse(dto.publishedAt!),
    );
  }

  TimetablePeriod toPeriod(TimetablePeriodDto dto) {
    return TimetablePeriod(
      id: dto.id,
      timetableId: dto.timetableId,
      dayOfWeek: dto.dayOfWeek,
      periodNumber: dto.periodNumber,
      subjectLabel: dto.subjectLabel,
      roomLabel: dto.roomLabel,
      teacherId: dto.teacherId,
    );
  }

  TeacherWorkloadEntry toWorkload(TeacherWorkloadDto dto) {
    return TeacherWorkloadEntry(
      teacherId: dto.teacherId,
      teacherName: dto.teacherName,
      periodCount: dto.periodCount,
      isOverloaded: dto.isOverloaded,
    );
  }

  TimetableConflict toConflict(TimetableConflictDto dto) {
    return TimetableConflict(
      type: TimetableConflictType.values.firstWhere(
        (type) => type.name == dto.type,
        orElse: () => TimetableConflictType.teacher,
      ),
      message: dto.message,
      dayOfWeek: dto.dayOfWeek,
      periodNumber: dto.periodNumber,
      entityId: dto.entityId,
    );
  }

  TimetableValidationResult toValidation(TimetableValidationResultDto dto) {
    return TimetableValidationResult(
      valid: dto.valid,
      conflictCount: dto.conflictCount,
      gapCount: dto.gapCount,
      conflicts: dto.conflicts.map(toConflict).toList(),
    );
  }
}
