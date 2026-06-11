class LessonEffectivenessScore {
  const LessonEffectivenessScore({
    required this.id,
    required this.className,
    required this.topic,
    required this.effectivenessScore,
    required this.completionRate,
    required this.studentEngagementScore,
    required this.syllabusAlignmentScore,
    required this.recordedOn,
    this.lessonLogId,
    this.subjectId,
  });

  final String id;
  final String? lessonLogId;
  final String className;
  final String? subjectId;
  final String topic;
  final int effectivenessScore;
  final int completionRate;
  final int studentEngagementScore;
  final int syllabusAlignmentScore;
  final String recordedOn;
}

class TopicMasteryEntry {
  const TopicMasteryEntry({
    required this.className,
    required this.topicName,
    required this.masteryPercent,
    required this.lessonsCompleted,
    required this.avgEffectivenessScore,
    this.subjectId,
  });

  final String className;
  final String? subjectId;
  final String topicName;
  final int masteryPercent;
  final int lessonsCompleted;
  final int avgEffectivenessScore;
}

class TeacherPerformanceInsights {
  const TeacherPerformanceInsights({
    required this.overallEffectivenessScore,
    required this.lessonsCompleted,
    required this.syllabusCoveragePercent,
    required this.avgStudentEngagement,
    required this.strengths,
    required this.improvementAreas,
    required this.recentHighlights,
  });

  final int overallEffectivenessScore;
  final int lessonsCompleted;
  final int syllabusCoveragePercent;
  final int avgStudentEngagement;
  final List<String> strengths;
  final List<String> improvementAreas;
  final List<String> recentHighlights;
}

class TeacherPlanningItem {
  const TeacherPlanningItem({
    required this.priority,
    required this.category,
    required this.action,
    this.dueHint,
  });

  final String priority;
  final String category;
  final String action;
  final String? dueHint;
}

class TeacherPlanningCenter {
  const TeacherPlanningCenter({
    required this.weeklyFocus,
    required this.pendingTopics,
    required this.upcomingAssessments,
    required this.planningItems,
  });

  final String weeklyFocus;
  final List<String> pendingTopics;
  final List<String> upcomingAssessments;
  final List<TeacherPlanningItem> planningItems;
}

class ParentMeetingSummarySections {
  const ParentMeetingSummarySections({
    required this.opening,
    required this.academicProgress,
    required this.attendance,
    required this.homework,
    required this.behavior,
    required this.strengths,
    required this.concerns,
    required this.actionItems,
    required this.closing,
  });

  final String opening;
  final String academicProgress;
  final String attendance;
  final String homework;
  final String behavior;
  final List<String> strengths;
  final List<String> concerns;
  final List<String> actionItems;
  final String closing;
}

class ParentMeetingSummary {
  const ParentMeetingSummary({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.meetingDate,
    required this.summary,
    required this.printable,
    this.id,
  });

  final String? id;
  final String studentId;
  final String studentName;
  final String className;
  final String meetingDate;
  final ParentMeetingSummarySections summary;
  final bool printable;
}
