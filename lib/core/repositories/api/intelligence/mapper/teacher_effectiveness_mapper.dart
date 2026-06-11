import '../../../../../features/intelligence/teacher_effectiveness/teacher_effectiveness_models.dart';

class TeacherEffectivenessMapper {
  const TeacherEffectivenessMapper();

  LessonEffectivenessScore lessonScoreFromApi(Map<String, dynamic> json) => LessonEffectivenessScore(
        id: json['id'] as String? ?? '',
        lessonLogId: json['lessonLogId'] as String? ?? json['lesson_log_id'] as String?,
        className: json['className'] as String? ?? json['class_name'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? json['subject_id'] as String?,
        topic: json['topic'] as String? ?? '',
        effectivenessScore:
            json['effectivenessScore'] as int? ?? json['effectiveness_score'] as int? ?? 0,
        completionRate: json['completionRate'] as int? ?? json['completion_rate'] as int? ?? 0,
        studentEngagementScore: json['studentEngagementScore'] as int? ??
            json['student_engagement_score'] as int? ??
            0,
        syllabusAlignmentScore: json['syllabusAlignmentScore'] as int? ??
            json['syllabus_alignment_score'] as int? ??
            0,
        recordedOn: json['recordedOn'] as String? ?? json['recorded_on'] as String? ?? '',
      );

  TopicMasteryEntry topicMasteryFromApi(Map<String, dynamic> json) => TopicMasteryEntry(
        className: json['className'] as String? ?? json['class_name'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? json['subject_id'] as String?,
        topicName: json['topicName'] as String? ?? json['topic_name'] as String? ?? '',
        masteryPercent: json['masteryPercent'] as int? ?? json['mastery_percent'] as int? ?? 0,
        lessonsCompleted: json['lessonsCompleted'] as int? ?? json['lessons_completed'] as int? ?? 0,
        avgEffectivenessScore: json['avgEffectivenessScore'] as int? ??
            json['avg_effectiveness_score'] as int? ??
            0,
      );

  TeacherPerformanceInsights performanceFromApi(Map<String, dynamic> json) => TeacherPerformanceInsights(
        overallEffectivenessScore: json['overallEffectivenessScore'] as int? ??
            json['overall_effectiveness_score'] as int? ??
            0,
        lessonsCompleted: json['lessonsCompleted'] as int? ?? json['lessons_completed'] as int? ?? 0,
        syllabusCoveragePercent: json['syllabusCoveragePercent'] as int? ??
            json['syllabus_coverage_percent'] as int? ??
            0,
        avgStudentEngagement:
            json['avgStudentEngagement'] as int? ?? json['avg_student_engagement'] as int? ?? 0,
        strengths: (json['strengths'] as List<dynamic>? ?? const []).cast<String>(),
        improvementAreas:
            (json['improvementAreas'] as List<dynamic>? ?? json['improvement_areas'] as List<dynamic>? ?? const [])
                .cast<String>(),
        recentHighlights:
            (json['recentHighlights'] as List<dynamic>? ?? json['recent_highlights'] as List<dynamic>? ?? const [])
                .cast<String>(),
      );

  TeacherPlanningCenter planningFromApi(Map<String, dynamic> json) {
    final itemsRaw = json['planningItems'] ?? json['planning_items'];
    return TeacherPlanningCenter(
      weeklyFocus: json['weeklyFocus'] as String? ?? json['weekly_focus'] as String? ?? '',
      pendingTopics:
          (json['pendingTopics'] as List<dynamic>? ?? json['pending_topics'] as List<dynamic>? ?? const [])
              .cast<String>(),
      upcomingAssessments: (json['upcomingAssessments'] as List<dynamic>? ??
              json['upcoming_assessments'] as List<dynamic>? ??
              const [])
          .cast<String>(),
      planningItems: itemsRaw is List
          ? itemsRaw
              .map((e) {
                final m = e as Map;
                return TeacherPlanningItem(
                  priority: m['priority'] as String? ?? 'medium',
                  category: m['category'] as String? ?? '',
                  action: m['action'] as String? ?? '',
                  dueHint: m['dueHint'] as String? ?? m['due_hint'] as String?,
                );
              })
              .toList()
          : const [],
    );
  }

  ParentMeetingSummary parentMeetingSummaryFromApi(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final summaryMap = summaryRaw is Map<String, dynamic> ? summaryRaw : const <String, dynamic>{};
    return ParentMeetingSummary(
      id: json['id'] as String?,
      studentId: json['studentId'] as String? ?? json['student_id'] as String? ?? '',
      studentName: json['studentName'] as String? ?? json['student_name'] as String? ?? '',
      className: json['className'] as String? ?? json['class_name'] as String? ?? '',
      meetingDate: json['meetingDate'] as String? ?? json['meeting_date'] as String? ?? '',
      printable: json['printable'] as bool? ?? true,
      summary: ParentMeetingSummarySections(
        opening: summaryMap['opening'] as String? ?? '',
        academicProgress: summaryMap['academicProgress'] as String? ??
            summaryMap['academic_progress'] as String? ??
            '',
        attendance: summaryMap['attendance'] as String? ?? '',
        homework: summaryMap['homework'] as String? ?? '',
        behavior: summaryMap['behavior'] as String? ?? '',
        strengths: (summaryMap['strengths'] as List<dynamic>? ?? const []).cast<String>(),
        concerns: (summaryMap['concerns'] as List<dynamic>? ?? const []).cast<String>(),
        actionItems: (summaryMap['actionItems'] as List<dynamic>? ??
                summaryMap['action_items'] as List<dynamic>? ??
                const [])
            .cast<String>(),
        closing: summaryMap['closing'] as String? ?? '',
      ),
    );
  }
}
