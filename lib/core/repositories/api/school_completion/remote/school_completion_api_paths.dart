abstract final class SchoolCompletionApiPaths {
  static const String subjects = '/school/subjects';
  static String subject(String id) => '/school/subjects/$id';
  static const String lessonLogs = '/school/lesson-logs';
  static const String timetableAutomate = '/school/timetables/automate';
  static const String branding = '/school/branding';
  static const String whatsAppProvider = '/school/whatsapp-provider';
  static const String whatsAppProviderTest = '/school/whatsapp-provider/test';
  static const String classSubjectAssignments =
      '/school/class-subject-assignments';
  static String classSubjectAssignment(String id) =>
      '/school/class-subject-assignments/$id';
  static const String teacherSubjectAssignments =
      '/school/teacher-subject-assignments';
  static const String subjectWorkload = '/school/subject-workload';
  static const String teacherLessonAnalytics =
      '/school/lesson-analytics/teacher';
  static const String principalLessonAnalytics =
      '/school/lesson-analytics/principal';
  static const String timetableOptimize = '/school/timetables/optimize';
  static const String timetableOptimizeApply =
      '/school/timetables/optimize/apply';
  static const String timetableSubstituteCoverage =
      '/school/timetables/substitute/coverage';
  static const String timetableSubstituteAssign =
      '/school/timetables/substitute/assign';
  static const String timetableTeacherReassignmentOptions =
      '/school/timetables/reassign/options';
  static const String timetableTeacherReassignment =
      '/school/timetables/reassign';
  static const String deliveryAnalytics =
      '/school/communications/delivery-analytics';
  static const String communicationAnalyticsSummary =
      '/school/communications/analytics/summary';
  static const String communicationAnalyticsCampaigns =
      '/school/communications/analytics/campaigns';
  static const String communicationAnalyticsDelivery =
      '/school/communications/analytics/delivery';
  static const String communicationAnalyticsEffectiveness =
      '/school/communications/analytics/effectiveness';
  static const String communicationAnalyticsParentEngagement =
      '/school/communications/analytics/parent-engagement';
  static const String communicationAnalyticsParentAdoption =
      '/school/communications/analytics/parent-adoption';
  static const String pilotDashboard = '/school/pilot/dashboard';
  static const String parentActivationDashboard =
      '/school/parent-activation/dashboard';
  static const String syllabusTemplates = '/school/syllabus/templates';
  static const String syllabusGenerate = '/school/syllabus/generate';
  static const String syllabusClone = '/school/syllabus/clone';
  static const String syllabusChapters = '/school/syllabus/chapters';
  static const String completeTopic = '/school/academic/complete-topic';
  static const String teacherProgress = '/school/academic/teacher-progress';
  static const String principalAcademicProgress =
      '/school/academic/principal-progress';
  static const String rooms = '/school/rooms';
  static const String roomsAllocate = '/school/rooms/allocate';
  static const String examTimetableGenerate = '/school/exam-timetable/generate';
  static const String timetableIntelligence = '/school/timetables/intelligence';
}
