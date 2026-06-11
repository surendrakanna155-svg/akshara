import '../../../../../features/school_completion/school_completion_models.dart';

/// Phase 10 DTO mappers for school completion API responses.
class SchoolCompletionPhase10Mapper {
  const SchoolCompletionPhase10Mapper();

  SubjectTemplate toSubjectTemplate(Map<String, dynamic> json) {
    final chaptersRaw = json['chapters'] as List? ?? [];
    return SubjectTemplate(
      id: json['id'] as String? ?? '',
      board: json['board'] as String? ?? 'CBSE',
      subjectCode: json['subjectCode'] as String? ?? json['subject_code'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? json['subject_name'] as String? ?? '',
      gradeLabel: json['gradeLabel'] as String? ?? json['grade_label'] as String? ?? '',
      chapters: [
        for (final c in chaptersRaw)
          SyllabusTemplateChapter(
            name: (c as Map)['name'] as String? ?? '',
            topics: (c['topics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          ),
      ],
    );
  }

  SyllabusGenerationResult toGenerationResult(Map<String, dynamic> json) => SyllabusGenerationResult(
        chaptersCreated: json['chaptersCreated'] as int? ?? json['chapters_created'] as int? ?? 0,
        topicsCreated: json['topicsCreated'] as int? ?? json['topics_created'] as int? ?? 0,
        generationId: json['generationId'] as String? ?? json['generation_id'] as String? ?? '',
      );

  SyllabusChapter toChapter(Map<String, dynamic> json) => SyllabusChapter(
        id: json['id'] as String? ?? '',
        academicYearId: json['academicYearId'] as String? ?? json['academic_year_id'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? json['subject_id'] as String? ?? '',
        className: json['className'] as String? ?? json['class_name'] as String? ?? '',
        chapterName: json['chapterName'] as String? ?? json['chapter_name'] as String? ?? '',
        sequenceOrder: json['sequenceOrder'] as int? ?? json['sequence_order'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
      );

  TeacherProgressDashboard toTeacherProgress(Map<String, dynamic> json) {
    final alerts = json['pendingAlerts'] ?? json['pending_alerts'];
    return TeacherProgressDashboard(
      topicsCompleted: json['topicsCompleted'] as int? ?? json['topics_completed'] as int? ?? 0,
      topicsPending: json['topicsPending'] as int? ?? json['topics_pending'] as int? ?? 0,
      chaptersCompleted: json['chaptersCompleted'] as int? ?? json['chapters_completed'] as int? ?? 0,
      chaptersTotal: json['chaptersTotal'] as int? ?? json['chapters_total'] as int? ?? 0,
      coveragePercent: json['coveragePercent'] as int? ?? json['coverage_percent'] as int? ?? 0,
      pendingAlerts: alerts is List ? alerts.map((e) => e.toString()).toList() : const [],
    );
  }

  PrincipalAcademicDashboard toPrincipalProgress(Map<String, dynamic> json) {
    final coverage = json['classCoverage'] ?? json['class_coverage'];
    return PrincipalAcademicDashboard(
      overallCoveragePercent:
          json['overallCoveragePercent'] as int? ?? json['overall_coverage_percent'] as int? ?? 0,
      classCoverage: coverage is List
          ? coverage.map((e) {
              final m = e as Map;
              return PrincipalClassCoverage(
                className: m['className'] as String? ?? m['class_name'] as String? ?? '',
                subjectId: m['subjectId'] as String? ?? m['subject_id'] as String? ?? '',
                coveragePercent: m['coveragePercent'] as int? ?? m['coverage_percent'] as int? ?? 0,
                pendingTopics: m['pendingTopics'] as int? ?? m['pending_topics'] as int? ?? 0,
              );
            }).toList()
          : const [],
    );
  }

  AcademicRoom toRoom(Map<String, dynamic> json) => AcademicRoom(
        id: json['id'] as String? ?? '',
        roomLabel: json['roomLabel'] as String? ?? json['room_label'] as String? ?? '',
        roomType: json['roomType'] as String? ?? json['room_type'] as String? ?? 'classroom',
        capacity: json['capacity'] as int? ?? 40,
        status: json['status'] as String? ?? 'active',
      );

  TimetableIntelligenceResult toIntelligence(Map<String, dynamic> json) {
    final util = json['roomUtilization'] ?? json['room_utilization'];
    final opt = json['optimization'] as Map?;
    return TimetableIntelligenceResult(
      intelligenceScore: json['intelligenceScore'] as int? ?? json['intelligence_score'] as int? ?? 0,
      examCount: json['examCount'] as int? ?? json['exam_count'] as int? ?? 0,
      conflictCount: opt?['conflictCount'] as int? ?? opt?['conflict_count'] as int? ?? 0,
      roomUtilization: util is List
          ? util.map((e) {
              final m = e as Map;
              return RoomUtilizationEntry(
                roomLabel: m['roomLabel'] as String? ?? m['room_label'] as String? ?? '',
                periodCount: m['periodCount'] as int? ?? m['period_count'] as int? ?? 0,
                capacity: m['capacity'] as int? ?? 0,
              );
            }).toList()
          : const [],
    );
  }
}
