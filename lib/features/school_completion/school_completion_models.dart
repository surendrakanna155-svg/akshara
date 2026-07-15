class AcademicSubject {
  const AcademicSubject({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.category,
    required this.gradeLabels,
    required this.status,
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final String category;
  final List<String> gradeLabels;
  final String status;
}

class LessonLogEntry {
  const LessonLogEntry({
    required this.id,
    required this.teacherUserId,
    required this.className,
    required this.topic,
    required this.outcome,
    required this.recordedOn,
    this.sectionName,
    this.subjectId,
    this.notes,
  });

  final String id;
  final String teacherUserId;
  final String className;
  final String? sectionName;
  final String? subjectId;
  final String topic;
  final String outcome;
  final String? notes;
  final String recordedOn;
}

class TimetableAutomationResult {
  const TimetableAutomationResult({
    required this.timetablesCreated,
    required this.subjectsUsed,
    required this.warnings,
    required this.conflictCount,
  });

  final int timetablesCreated;
  final List<String> subjectsUsed;
  final List<String> warnings;
  final int conflictCount;
}

class SchoolBranding {
  const SchoolBranding({
    required this.displayName,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    this.logoUrl,
    this.faviconUrl,
    this.loginBackgroundUrl,
  });

  final String displayName;
  final String tagline;
  final String primaryColor;
  final String secondaryColor;
  final String? logoUrl;
  final String? faviconUrl;
  final String? loginBackgroundUrl;
}

class WhatsAppProviderConfig {
  const WhatsAppProviderConfig({
    required this.provider,
    required this.isActive,
    this.id,
    this.senderId,
    this.apiKeyRef,
    this.templateNamespace,
  });

  final String? id;
  final String provider;
  final String? senderId;
  final String? apiKeyRef;
  final String? templateNamespace;
  final bool isActive;
}

class WhatsAppTestResult {
  const WhatsAppTestResult({
    required this.success,
    this.providerRef,
    this.error,
  });

  final bool success;
  final String? providerRef;
  final String? error;
}

class ClassSubjectAssignment {
  const ClassSubjectAssignment({
    required this.id,
    required this.academicYearId,
    required this.classId,
    required this.subjectId,
    required this.isElective,
    required this.periodsPerWeek,
    required this.status,
    this.sectionId,
  });

  final String id;
  final String academicYearId;
  final String classId;
  final String? sectionId;
  final String subjectId;
  final bool isElective;
  final int periodsPerWeek;
  final String status;
}

class TeacherSubjectAssignment {
  const TeacherSubjectAssignment({
    required this.id,
    required this.academicYearId,
    required this.teacherUserId,
    required this.subjectId,
    required this.periodsPerWeek,
    required this.isPrimary,
    required this.status,
    this.classId,
    this.sectionId,
  });

  final String id;
  final String academicYearId;
  final String teacherUserId;
  final String subjectId;
  final String? classId;
  final String? sectionId;
  final int periodsPerWeek;
  final bool isPrimary;
  final String status;
}

class SubjectWorkloadEntry {
  const SubjectWorkloadEntry({
    required this.teacherUserId,
    required this.subjectId,
    required this.totalPeriods,
    required this.assignmentCount,
    required this.isOverloaded,
  });

  final String teacherUserId;
  final String subjectId;
  final int totalPeriods;
  final int assignmentCount;
  final bool isOverloaded;
}

class TeacherLessonAnalytics {
  const TeacherLessonAnalytics({
    required this.completedLessons,
    required this.pendingLessons,
    required this.coveragePercent,
    required this.pendingTopics,
    this.upcomingRisk,
  });

  final int completedLessons;
  final int pendingLessons;
  final int coveragePercent;
  final List<String> pendingTopics;
  final String? upcomingRisk;
}

class PrincipalCoverageEntry {
  const PrincipalCoverageEntry({
    required this.className,
    required this.coveragePercent,
    required this.completedTopics,
    required this.totalTopics,
    required this.pendingTopics,
    this.subjectId,
  });

  final String className;
  final String? subjectId;
  final int coveragePercent;
  final int completedTopics;
  final int totalTopics;
  final List<String> pendingTopics;
}

class TimetableOptimizationResult {
  const TimetableOptimizationResult({
    required this.qualityScore,
    required this.overloadAlerts,
    required this.freePeriodAnalysis,
    required this.conflictCount,
    required this.substituteSuggestions,
    required this.recommendations,
  });

  final int qualityScore;
  final List<TimetableOverloadAlert> overloadAlerts;
  final List<TimetableFreePeriodEntry> freePeriodAnalysis;
  final int conflictCount;
  final List<TimetableSubstituteSuggestion> substituteSuggestions;
  final List<TimetableRecommendation> recommendations;
}

class TimetableOverloadAlert {
  const TimetableOverloadAlert({
    required this.teacherId,
    required this.teacherName,
    required this.periodCount,
  });

  final String teacherId;
  final String teacherName;
  final int periodCount;
}

class TimetableFreePeriodEntry {
  const TimetableFreePeriodEntry({
    required this.teacherId,
    required this.teacherName,
    required this.freePeriods,
  });

  final String teacherId;
  final String teacherName;
  final int freePeriods;
}

class TimetableSubstituteSuggestion {
  const TimetableSubstituteSuggestion({
    required this.conflictMessage,
    required this.suggestion,
  });

  final String conflictMessage;
  final String suggestion;
}

class TimetableRecommendation {
  const TimetableRecommendation({
    this.recommendationId,
    required this.kind,
    required this.title,
    required this.detail,
    required this.readOnly,
  });

  final String? recommendationId;
  final String kind;
  final String title;
  final String detail;
  final bool readOnly;
}

class ApplyTimetableOptimizationRequest {
  const ApplyTimetableOptimizationRequest({
    required this.academicYearId,
    this.recommendationIds = const [],
    this.applyAll = false,
  });

  final String academicYearId;
  final List<String> recommendationIds;
  final bool applyAll;
}

class ApplyTimetableOptimizationResult {
  const ApplyTimetableOptimizationResult({
    required this.appliedRecommendationIds,
    required this.appliedCount,
    required this.updatedConflictCount,
    required this.updatedQualityScore,
    required this.message,
  });

  final List<String> appliedRecommendationIds;
  final int appliedCount;
  final int updatedConflictCount;
  final int updatedQualityScore;
  final String message;
}

class DeliveryAnalytics {
  const DeliveryAnalytics({
    required this.totalSent,
    required this.totalFailed,
    required this.totalPending,
    required this.deliveryRate,
    required this.byChannel,
    required this.recentEvents,
  });

  final int totalSent;
  final int totalFailed;
  final int totalPending;
  final int deliveryRate;
  final Map<String, DeliveryChannelStats> byChannel;
  final List<DeliveryEvent> recentEvents;
}

class DeliveryChannelStats {
  const DeliveryChannelStats({
    required this.sent,
    required this.failed,
    required this.pending,
  });

  final int sent;
  final int failed;
  final int pending;
}

class DeliveryEvent {
  const DeliveryEvent({
    required this.id,
    required this.channel,
    required this.recipientLabel,
    required this.status,
    required this.createdAt,
    this.templateCode,
    this.providerRef,
    this.errorMessage,
  });

  final String id;
  final String channel;
  final String? templateCode;
  final String recipientLabel;
  final String status;
  final String? providerRef;
  final String? errorMessage;
  final String createdAt;
}

class PilotDashboardSnapshot {
  const PilotDashboardSnapshot({
    required this.onboardingStatus,
    required this.setupWizardCompleted,
    required this.importHealth,
    required this.teacherActivation,
    required this.parentActivation,
    required this.otpDelivery,
    required this.pilotScore,
  });

  final String onboardingStatus;
  final bool setupWizardCompleted;
  final PilotImportHealth importHealth;
  final PilotActivationStats teacherActivation;
  final PilotActivationStats parentActivation;
  final PilotOtpDelivery otpDelivery;
  final int pilotScore;
}

class PilotImportHealth {
  const PilotImportHealth({
    required this.totalJobs,
    required this.committedJobs,
    required this.failedRows,
    this.lastImportAt,
  });

  final int totalJobs;
  final int committedJobs;
  final int failedRows;
  final String? lastImportAt;
}

class PilotActivationStats {
  const PilotActivationStats({
    required this.total,
    required this.active,
    required this.pending,
    required this.activationRate,
    this.adoptionRate = 0,
    this.dailyActiveParents = 0,
    this.monthlyActiveParents = 0,
  });

  final int total;
  final int active;
  final int pending;
  final int activationRate;
  final int adoptionRate;
  final int dailyActiveParents;
  final int monthlyActiveParents;
}

class RoomAllocationResult {
  const RoomAllocationResult({
    required this.allocatedPeriods,
    required this.labAssignments,
    required this.conflictsResolved,
  });

  final int allocatedPeriods;
  final int labAssignments;
  final int conflictsResolved;
}

class PilotOtpDelivery {
  const PilotOtpDelivery({
    required this.sentLast7Days,
    required this.failedLast7Days,
    required this.deliveryRate,
  });

  final int sentLast7Days;
  final int failedLast7Days;
  final int deliveryRate;
}

class SubjectTemplate {
  const SubjectTemplate({
    required this.id,
    required this.board,
    required this.subjectCode,
    required this.subjectName,
    required this.gradeLabel,
    required this.chapters,
  });

  final String id;
  final String board;
  final String subjectCode;
  final String subjectName;
  final String gradeLabel;
  final List<SyllabusTemplateChapter> chapters;
}

class SyllabusTemplateChapter {
  const SyllabusTemplateChapter({required this.name, required this.topics});
  final String name;
  final List<String> topics;
}

class SyllabusGenerationResult {
  const SyllabusGenerationResult({
    required this.chaptersCreated,
    required this.topicsCreated,
    required this.generationId,
  });

  final int chaptersCreated;
  final int topicsCreated;
  final String generationId;
}

class SyllabusChapter {
  const SyllabusChapter({
    required this.id,
    required this.academicYearId,
    required this.subjectId,
    required this.className,
    required this.chapterName,
    required this.sequenceOrder,
    required this.status,
  });

  final String id;
  final String academicYearId;
  final String subjectId;
  final String className;
  final String chapterName;
  final int sequenceOrder;
  final String status;
}

/// A REAL syllabus topic row (`syllabus_topics.id` is the value
/// [SchoolCompletionRepository.completeTopic] must receive as `topicId` — the
/// daily-capture UI previously fabricated this id, which failed the
/// `syllabus_topic_completions` FK; see `listSyllabusTopics`).
class SyllabusTopic {
  const SyllabusTopic({
    required this.id,
    required this.subjectId,
    required this.className,
    required this.chapterId,
    required this.topicName,
    required this.sequenceOrder,
    required this.status,
  });

  final String id;
  final String subjectId;
  final String className;
  final String? chapterId;
  final String topicName;
  final int sequenceOrder;
  final String status;
}

class TeacherProgressDashboard {
  const TeacherProgressDashboard({
    required this.topicsCompleted,
    required this.topicsPending,
    required this.chaptersCompleted,
    required this.chaptersTotal,
    required this.coveragePercent,
    required this.pendingAlerts,
  });

  final int topicsCompleted;
  final int topicsPending;
  final int chaptersCompleted;
  final int chaptersTotal;
  final int coveragePercent;
  final List<String> pendingAlerts;
}

class PrincipalAcademicDashboard {
  const PrincipalAcademicDashboard({
    required this.classCoverage,
    required this.overallCoveragePercent,
  });

  final List<PrincipalClassCoverage> classCoverage;
  final int overallCoveragePercent;
}

class PrincipalClassCoverage {
  const PrincipalClassCoverage({
    required this.className,
    required this.subjectId,
    required this.coveragePercent,
    required this.pendingTopics,
  });

  final String className;
  final String subjectId;
  final int coveragePercent;
  final int pendingTopics;
}

class AcademicRoom {
  const AcademicRoom({
    required this.id,
    required this.roomLabel,
    required this.roomType,
    required this.capacity,
    required this.status,
  });

  final String id;
  final String roomLabel;
  final String roomType;
  final int capacity;
  final String status;
}

class TimetableIntelligenceResult {
  const TimetableIntelligenceResult({
    required this.intelligenceScore,
    required this.examCount,
    required this.roomUtilization,
    required this.conflictCount,
  });

  final int intelligenceScore;
  final int examCount;
  final List<RoomUtilizationEntry> roomUtilization;
  final int conflictCount;
}

class RoomUtilizationEntry {
  const RoomUtilizationEntry({
    required this.roomLabel,
    required this.periodCount,
    required this.capacity,
  });

  final String roomLabel;
  final int periodCount;
  final int capacity;
}

class SubstituteOpenSlot {
  const SubstituteOpenSlot({
    required this.slotId,
    required this.academicYearId,
    required this.className,
    required this.sectionName,
    required this.subjectName,
    required this.originalTeacherId,
    required this.originalTeacherName,
    required this.dayOfWeek,
    required this.periodLabel,
    required this.slotDate,
  });

  final String slotId;
  final String academicYearId;
  final String className;
  final String sectionName;
  final String subjectName;
  final String originalTeacherId;
  final String originalTeacherName;
  final String dayOfWeek;
  final String periodLabel;
  final String slotDate;
}

class SubstituteTeacherCandidate {
  const SubstituteTeacherCandidate({
    required this.teacherId,
    required this.teacherName,
    required this.subjects,
    required this.freePeriods,
    required this.dailyLoad,
    required this.canNotify,
  });

  final String teacherId;
  final String teacherName;
  final List<String> subjects;
  final int freePeriods;
  final int dailyLoad;
  final bool canNotify;
}

class SubstituteCoverageData {
  const SubstituteCoverageData({
    required this.openSlots,
    required this.candidates,
    required this.generatedAt,
  });

  final List<SubstituteOpenSlot> openSlots;
  final List<SubstituteTeacherCandidate> candidates;
  final String generatedAt;
}

class AssignSubstituteRequest {
  const AssignSubstituteRequest({
    required this.slotId,
    required this.substituteTeacherId,
    required this.notifySubstituteTeacher,
    required this.notifyClassIncharge,
    required this.notifyStudents,
  });

  final String slotId;
  final String substituteTeacherId;
  final bool notifySubstituteTeacher;
  final bool notifyClassIncharge;
  final bool notifyStudents;
}

class SubstituteAssignmentResult {
  const SubstituteAssignmentResult({
    required this.assignmentId,
    required this.slotId,
    required this.timetableUpdated,
    required this.notifiedAudience,
    required this.message,
  });

  final String assignmentId;
  final String slotId;
  final bool timetableUpdated;
  final List<String> notifiedAudience;
  final String message;
}

class TeacherReassignmentSlot {
  const TeacherReassignmentSlot({
    required this.slotId,
    required this.academicYearId,
    required this.sourceTeacherId,
    required this.sourceTeacherName,
    required this.className,
    required this.sectionName,
    required this.subjectName,
    required this.dayOfWeek,
    required this.periodLabel,
    required this.slotDate,
  });

  final String slotId;
  final String academicYearId;
  final String sourceTeacherId;
  final String sourceTeacherName;
  final String className;
  final String sectionName;
  final String subjectName;
  final String dayOfWeek;
  final String periodLabel;
  final String slotDate;
}

class TeacherReassignmentCandidate {
  const TeacherReassignmentCandidate({
    required this.teacherId,
    required this.teacherName,
    required this.subjects,
    required this.freePeriods,
    required this.dailyLoad,
    required this.canNotify,
  });

  final String teacherId;
  final String teacherName;
  final List<String> subjects;
  final int freePeriods;
  final int dailyLoad;
  final bool canNotify;
}

class TeacherReassignmentData {
  const TeacherReassignmentData({
    required this.sourceTeacherId,
    required this.sourceTeacherName,
    required this.slots,
    required this.candidates,
    required this.generatedAt,
  });

  final String sourceTeacherId;
  final String sourceTeacherName;
  final List<TeacherReassignmentSlot> slots;
  final List<TeacherReassignmentCandidate> candidates;
  final String generatedAt;
}

class ReassignTeacherRequest {
  const ReassignTeacherRequest({
    required this.academicYearId,
    required this.sourceTeacherId,
    required this.targetTeacherId,
    required this.slotIds,
    required this.notifySourceTeacher,
    required this.notifyTargetTeacher,
    required this.notifyStudents,
  });

  final String academicYearId;
  final String sourceTeacherId;
  final String targetTeacherId;
  final List<String> slotIds;
  final bool notifySourceTeacher;
  final bool notifyTargetTeacher;
  final bool notifyStudents;
}

class TeacherReassignmentResult {
  const TeacherReassignmentResult({
    required this.reassignmentId,
    required this.sourceTeacherId,
    required this.targetTeacherId,
    required this.updatedSlotIds,
    required this.notifiedAudience,
    required this.message,
  });

  final String reassignmentId;
  final String sourceTeacherId;
  final String targetTeacherId;
  final List<String> updatedSlotIds;
  final List<String> notifiedAudience;
  final String message;
}

class CampaignSummary {
  const CampaignSummary({
    required this.id,
    required this.campaignCode,
    required this.campaignName,
    required this.channel,
    required this.status,
    required this.sentCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.openRate,
    required this.responseRate,
    this.templateCode,
  });

  final String id;
  final String campaignCode;
  final String campaignName;
  final String channel;
  final String? templateCode;
  final String status;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final int openRate;
  final int responseRate;
}

class CampaignAnalytics {
  const CampaignAnalytics({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.aggregateDeliveryRate,
    required this.aggregateOpenRate,
    required this.aggregateResponseRate,
    required this.campaigns,
  });

  final int totalCampaigns;
  final int activeCampaigns;
  final int aggregateDeliveryRate;
  final int aggregateOpenRate;
  final int aggregateResponseRate;
  final List<CampaignSummary> campaigns;
}

class AnalyticsDeliveryTrendPoint {
  const AnalyticsDeliveryTrendPoint({
    required this.date,
    required this.sent,
    required this.failed,
  });

  final String date;
  final int sent;
  final int failed;
}

class AnalyticsDeliverySnapshot {
  const AnalyticsDeliverySnapshot({
    required this.totalSent,
    required this.totalFailed,
    required this.totalPending,
    required this.deliveryRate,
    required this.byChannel,
    required this.last7DaysSent,
    required this.last7DaysFailed,
    required this.trend,
  });

  final int totalSent;
  final int totalFailed;
  final int totalPending;
  final int deliveryRate;
  final Map<String, DeliveryChannelStats> byChannel;
  final int last7DaysSent;
  final int last7DaysFailed;
  final List<AnalyticsDeliveryTrendPoint> trend;
}

class TemplateEffectiveness {
  const TemplateEffectiveness({
    required this.templateCode,
    required this.sent,
    required this.openRate,
  });

  final String templateCode;
  final int sent;
  final int openRate;
}

class ChannelEffectiveness {
  const ChannelEffectiveness({
    required this.sent,
    required this.openRate,
    required this.responseRate,
  });

  final int sent;
  final int openRate;
  final int responseRate;
}

class CommunicationEffectiveness {
  const CommunicationEffectiveness({
    required this.effectivenessScore,
    required this.openRate,
    required this.responseRate,
    required this.topTemplates,
    required this.channelEffectiveness,
  });

  final int effectivenessScore;
  final int openRate;
  final int responseRate;
  final List<TemplateEffectiveness> topTemplates;
  final Map<String, ChannelEffectiveness> channelEffectiveness;
}

class ParentEngagementEntry {
  const ParentEngagementEntry({
    required this.parentUserId,
    required this.engagementScore,
    required this.messagesRead30d,
    required this.appSessions30d,
    this.lastActiveAt,
  });

  final String parentUserId;
  final int engagementScore;
  final int messagesRead30d;
  final int appSessions30d;
  final String? lastActiveAt;
}

class EngagementTrendPoint {
  const EngagementTrendPoint({required this.period, required this.score});

  final String period;
  final int score;
}

class ParentEngagementAnalytics {
  const ParentEngagementAnalytics({
    required this.averageEngagementScore,
    required this.activeParents30d,
    required this.lowEngagementParents,
    required this.topEngagedParents,
    required this.engagementTrend,
  });

  final int averageEngagementScore;
  final int activeParents30d;
  final int lowEngagementParents;
  final List<ParentEngagementEntry> topEngagedParents;
  final List<EngagementTrendPoint> engagementTrend;
}

class ParentAdoptionByGrade {
  const ParentAdoptionByGrade({
    required this.gradeLabel,
    required this.total,
    required this.active,
    required this.rate,
  });

  final String gradeLabel;
  final int total;
  final int active;
  final int rate;
}

class ParentAdoptionAnalytics {
  const ParentAdoptionAnalytics({
    required this.totalParents,
    required this.activeParents,
    required this.pendingParents,
    required this.adoptionRate,
    required this.newActivations30d,
    required this.adoptionByGrade,
  });

  final int totalParents;
  final int activeParents;
  final int pendingParents;
  final int adoptionRate;
  final int newActivations30d;
  final List<ParentAdoptionByGrade> adoptionByGrade;
}

class CommunicationAnalyticsSummary {
  const CommunicationAnalyticsSummary({
    required this.campaigns,
    required this.delivery,
    required this.effectiveness,
    required this.parentEngagement,
    required this.parentAdoption,
  });

  final CampaignAnalytics campaigns;
  final AnalyticsDeliverySnapshot delivery;
  final CommunicationEffectiveness effectiveness;
  final ParentEngagementAnalytics parentEngagement;
  final ParentAdoptionAnalytics parentAdoption;
}
