import 'package:akshara_erp/features/academic/timetable/timetable_models.dart';

class TimetableFixtureBuilder {
  Map<String, dynamic> envelope(Map<String, dynamic> data) {
    return {'success': true, 'data': data};
  }

  Map<String, dynamic> summaryEnvelope(TimetableSummary summary) {
    return envelope({
      'academicYearId': summary.academicYearId,
      'totalTimetables': summary.totalTimetables,
      'draftCount': summary.draftCount,
      'validatedCount': summary.validatedCount,
      'publishedCount': summary.publishedCount,
      'conflictCount': summary.conflictCount,
      'gapCount': summary.gapCount,
      'overloadedTeacherCount': summary.overloadedTeacherCount,
    });
  }

  Map<String, dynamic> entriesEnvelope(List<TimetableEntry> entries) {
    return envelope({
      'items': [
        for (final entry in entries)
          {
            'id': entry.id,
            'academicYearId': entry.academicYearId,
            'sectionId': entry.sectionId,
            'status': entry.status.name,
            'version': entry.version,
            'periodsPerDay': entry.periodsPerDay,
            'daysPerWeek': entry.daysPerWeek,
            'updatedAt': entry.updatedAt.toIso8601String(),
            'publishedAt': entry.publishedAt?.toIso8601String(),
          },
      ],
    });
  }

  Map<String, dynamic> workloadEnvelope(List<TeacherWorkloadEntry> entries) {
    return envelope({
      'items': [
        for (final entry in entries)
          {
            'teacherId': entry.teacherId,
            'teacherName': entry.teacherName,
            'periodCount': entry.periodCount,
            'isOverloaded': entry.isOverloaded,
          },
      ],
    });
  }
}
