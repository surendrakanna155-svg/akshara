import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';

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

  /// GET /academic/timetables/substitutions — resolved subs + server on-leave.
  Map<String, dynamic> dailySubstitutionsEnvelope(
    DailySubstitutionsBundle bundle,
  ) {
    return envelope({
      'date': bundle.date,
      'substitutions': [
        for (final s in bundle.substitutions)
          {
            'id': s.id,
            'periodId': s.periodId,
            'subDate': s.subDate,
            'originalTeacherId': s.originalTeacherId,
            'substituteTeacherId': s.substituteTeacherId,
            'reason': s.reason,
            'sectionId': s.sectionId,
            'dayOfWeek': s.dayOfWeek,
            'periodNumber': s.periodNumber,
            'subjectLabel': s.subjectLabel,
            'roomLabel': s.roomLabel,
          },
      ],
      'onLeave': [
        for (final t in bundle.onLeave)
          {
            'teacherId': t.teacherId,
            'fromDate': t.fromDate,
            'toDate': t.toDate,
            'reason': t.reason,
          },
      ],
    });
  }

  /// POST /academic/timetables/substitutions → `{ substitution: <SubstitutionRow> }`
  /// (snake_case, mirroring the raw DB row the backend returns on create).
  Map<String, dynamic> createSubstitutionEnvelope(TimetableSubstitution s) {
    return envelope({
      'substitution': {
        'id': s.id,
        'period_id': s.periodId,
        'sub_date': s.subDate,
        'original_teacher_id': s.originalTeacherId,
        'substitute_teacher_id': s.substituteTeacherId,
        'reason': s.reason,
      },
    });
  }

  /// A `{ data: null, error: { code, message } }` error envelope.
  Map<String, dynamic> errorEnvelope(String code, String message) {
    return {
      'data': null,
      'error': {'code': code, 'message': message},
    };
  }
}
