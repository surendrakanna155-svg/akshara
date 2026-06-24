enum EduDifficulty { easy, medium, hard, mixed }

enum EduQuestionType {
  mcq,
  fillBlank,
  match,
  shortAnswer,
  longAnswer,
  diagram,
}

enum EduExamType {
  unitTest,
  weeklyTest,
  monthlyTest,
  quarterly,
  halfYearly,
  annual,
}

enum EduHomeworkType {
  homework,
  practiceWorksheet,
  revisionWorksheet,
  holidayHomework,
}

enum EduRemarkType { principal, classTeacher, subjectTeacher }

enum EduRemarkLanguage { english, telugu, hindi }

/// Batch 8b/8c — Question Intelligence program tracks.
enum EduProgramTrack { board, jeeFoundation, neetFoundation, ntse, olympiad }

/// Bloom-style cognitive level for a bank item (optional metadata).
enum EduCognitiveLevel { remember, understand, apply, analyze, hots }

/// Paper-level approval lifecycle (governance, mirrors marks approval).
enum EduPaperReviewStatus {
  draft,
  submitted,
  changesRequested,
  approved,
  published,
  archived,
}

class QuestionBankItem {
  const QuestionBankItem({
    required this.id,
    required this.subjectName,
    required this.chapter,
    required this.topic,
    required this.difficulty,
    required this.questionType,
    required this.marks,
    required this.questionText,
    this.answerText,
    this.options = const [],
    this.status = 'active',
    this.programTrack = EduProgramTrack.board,
    this.cognitiveLevel,
    this.syllabusChapterId,
    this.sourceReference,
    this.reviewStatus = 'approved',
  });

  final String id;
  final String subjectName;
  final String chapter;
  final String topic;
  final EduDifficulty difficulty;
  final EduQuestionType questionType;
  final int marks;
  final String questionText;
  final String? answerText;
  final List<String> options;
  final String status;
  final EduProgramTrack programTrack;
  final EduCognitiveLevel? cognitiveLevel;
  final String? syllabusChapterId;
  final String? sourceReference;

  /// Per-row moderation state: pending | approved | rejected.
  final String reviewStatus;
}

class QuestionPaperSummary {
  const QuestionPaperSummary({
    required this.id,
    required this.title,
    required this.className,
    this.sectionName,
    required this.subjectName,
    required this.examType,
    required this.totalMarks,
    required this.difficulty,
    required this.status,
    this.reviewStatus = EduPaperReviewStatus.draft,
    this.programTrack = EduProgramTrack.board,
    this.bankReuseCount,
    this.aiGeneratedCount,
  });

  final String id;
  final String title;
  final String className;
  final String? sectionName;
  final String subjectName;
  final EduExamType examType;
  final int totalMarks;
  final EduDifficulty difficulty;

  /// Legacy lifecycle (draft | published | archived) kept for back-compat.
  final String status;

  /// Governance lifecycle that gates publishing (Batch 8b).
  final EduPaperReviewStatus reviewStatus;
  final EduProgramTrack programTrack;
  final int? bankReuseCount;
  final int? aiGeneratedCount;
}

class QuestionPaperDetail {
  const QuestionPaperDetail({
    required this.paper,
    required this.items,
    required this.blueprint,
    required this.answerKey,
    this.aiCandidateCount = 0,
    this.unfilledGapCount = 0,
    this.gaps = const [],
  });

  final QuestionPaperSummary paper;
  final List<QuestionPaperItem> items;
  final Map<String, dynamic> blueprint;
  final List<Map<String, dynamic>> answerKey;

  /// Generation diagnostics (populated only by generate; 0/empty when fetched).
  final int aiCandidateCount;
  final int unfilledGapCount;
  final List<PaperGap> gaps;

  /// Total marks the blueprint left unfilled (bank empty + AI off/declined).
  int get unfilledMarks => gaps.fold(0, (sum, gap) => sum + gap.marks);

  /// Items still awaiting moderation (AI candidates).
  List<QuestionPaperItem> get pendingAiItems =>
      items.where((i) => i.source == 'ai_candidate' && i.reviewStatus == 'pending').toList();
}

class QuestionPaperItem {
  const QuestionPaperItem({
    required this.questionNumber,
    required this.questionType,
    required this.marks,
    required this.questionText,
    this.id,
    this.answerText,
    this.options = const [],
    this.source = 'bank',
    this.reviewStatus = 'approved',
  });

  /// Server item id; null for not-yet-persisted generation previews.
  final String? id;
  final int questionNumber;
  final EduQuestionType questionType;
  final int marks;
  final String questionText;
  final String? answerText;
  final List<String> options;

  /// bank | ai_generated | ai_candidate
  final String source;

  /// pending | approved | rejected (only meaningful for ai_candidate).
  final String reviewStatus;
}

/// A blueprint slot the bank could not fill (and AI did not author).
class PaperGap {
  const PaperGap({
    required this.questionType,
    required this.difficulty,
    required this.marks,
    required this.chapter,
  });

  final EduQuestionType questionType;
  final String difficulty;
  final int marks;
  final String chapter;
}

/// Result of a bulk question-bank import.
class QuestionImportResult {
  const QuestionImportResult({required this.imported, required this.skippedDuplicates});

  final int imported;
  final int skippedDuplicates;
}

/// One round of the paper review/approval governance trail.
class PaperReview {
  const PaperReview({
    required this.id,
    required this.roundNumber,
    required this.status,
    this.comments,
    this.createdAt,
  });

  final String id;
  final int roundNumber;
  final String status;
  final String? comments;
  final DateTime? createdAt;
}

class GenerateQuestionPaperRequest {
  const GenerateQuestionPaperRequest({
    required this.academicYearLabel,
    required this.className,
    this.sectionName,
    required this.subjectName,
    required this.chapters,
    required this.difficulty,
    required this.totalMarks,
    required this.examType,
    this.programTrack = EduProgramTrack.board,
    this.allowAiGapFill = true,
  });

  final String academicYearLabel;
  final String className;
  final String? sectionName;
  final String subjectName;
  final List<String> chapters;
  final EduDifficulty difficulty;
  final int totalMarks;
  final EduExamType examType;
  final EduProgramTrack programTrack;

  /// When true (default) blueprint gaps the bank can't fill are offered to
  /// Claude as moderation candidates (never auto-published). When false, gaps
  /// are reported and left unfilled.
  final bool allowAiGapFill;
}

class HomeworkAssignment {
  const HomeworkAssignment({
    required this.id,
    required this.title,
    required this.className,
    this.sectionName,
    required this.subjectName,
    required this.topic,
    required this.difficulty,
    required this.assignmentType,
    required this.content,
    required this.status,
    this.dueDate,
  });

  final String id;
  final String title;
  final String className;
  final String? sectionName;
  final String subjectName;
  final String topic;
  final EduDifficulty difficulty;
  final EduHomeworkType assignmentType;
  final List<Map<String, String>> content;
  final String status;
  final DateTime? dueDate;
}

class GenerateHomeworkRequest {
  const GenerateHomeworkRequest({
    required this.academicYearLabel,
    required this.className,
    this.sectionName,
    required this.subjectName,
    required this.topic,
    required this.difficulty,
    required this.assignmentType,
    this.dueDate,
  });

  final String academicYearLabel;
  final String className;
  final String? sectionName;
  final String subjectName;
  final String topic;
  final EduDifficulty difficulty;
  final EduHomeworkType assignmentType;
  final DateTime? dueDate;
}

class ReportRemarkInputs {
  const ReportRemarkInputs({
    this.attendancePercent,
    this.averageMarks,
    this.strengths = const [],
    this.weaknesses = const [],
    this.activities = const [],
    this.subjectName,
  });

  final double? attendancePercent;
  final double? averageMarks;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> activities;
  final String? subjectName;

  Map<String, dynamic> toJson() => {
        if (attendancePercent != null) 'attendancePercent': attendancePercent,
        if (averageMarks != null) 'averageMarks': averageMarks,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'activities': activities,
        if (subjectName != null) 'subjectName': subjectName,
      };
}

class ReportCardRemark {
  const ReportCardRemark({
    required this.id,
    required this.studentId,
    required this.academicYearLabel,
    required this.remarkType,
    required this.language,
    required this.displayRemark,
    required this.status,
    this.generatedRemark,
    this.editedRemark,
  });

  final String id;
  final String studentId;
  final String academicYearLabel;
  final EduRemarkType remarkType;
  final EduRemarkLanguage language;
  final String displayRemark;
  final String status;
  final String? generatedRemark;
  final String? editedRemark;
}

class GenerateReportRemarkRequest {
  const GenerateReportRemarkRequest({
    required this.studentId,
    required this.academicYearLabel,
    required this.remarkType,
    required this.language,
    required this.inputs,
  });

  final String studentId;
  final String academicYearLabel;
  final EduRemarkType remarkType;
  final EduRemarkLanguage language;
  final ReportRemarkInputs inputs;
}
