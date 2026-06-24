import '../../../features/education/education_models.dart';
import '../repository_query.dart';

abstract class EducationRepository {
  Future<List<QuestionBankItem>> listQuestionBank({
    required RepositoryQuery query,
    String? subjectName,
    String? search,
  });

  Future<QuestionBankItem> createQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  });

  /// Bulk-import question-bank items (server de-dupes by fingerprint).
  Future<QuestionImportResult> importQuestionBank({
    required RepositoryQuery query,
    required List<QuestionBankItem> items,
  });

  /// Edit a saved bank question in place (Feature C, token-free). [item.id]
  /// identifies the row; its fields carry the new values.
  Future<QuestionBankItem> updateQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  });

  Future<List<QuestionPaperSummary>> listQuestionPapers({
    required RepositoryQuery query,
  });

  Future<QuestionPaperDetail> generateQuestionPaper({
    required RepositoryQuery query,
    required GenerateQuestionPaperRequest request,
  });

  Future<QuestionPaperDetail> getQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  });

  Future<QuestionPaperSummary> publishQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  });

  /// Submit a draft (or changes-requested) paper for review.
  Future<QuestionPaperSummary> submitQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  });

  /// Reviewer decision on a submitted paper: 'approved' | 'changes_requested'.
  Future<QuestionPaperSummary> reviewQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
    required String decision,
    String? comments,
  });

  Future<List<PaperReview>> listPaperReviews({
    required RepositoryQuery query,
    required String paperId,
  });

  /// Moderate an AI-candidate paper item: 'approved' | 'rejected'.
  Future<QuestionPaperItem> moderatePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    required String decision,
  });

  /// Edit one question inside a paper (Feature A, token-free). Editing an
  /// approved paper resets it to draft (re-approval required).
  Future<QuestionPaperItem> updatePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    EduQuestionType? questionType,
    int? marks,
    String? questionText,
    String? answerText,
    List<String>? options,
  });

  /// Regenerate one question slot with AI (Feature B — spends tokens). The new
  /// question returns as a pending AI candidate that must be re-moderated.
  Future<QuestionPaperItem> regeneratePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    String? chapter,
  });

  /// Save an approved AI-candidate paper item into the reusable bank
  /// (Feature E, token-free).
  Future<QuestionBankItem> promotePaperItemToBank({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    String? chapter,
    String? topic,
    EduDifficulty? difficulty,
    EduCognitiveLevel? cognitiveLevel,
    String? syllabusChapterId,
    String? learningOutcome,
  });

  Future<Map<String, dynamic>> exportQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  });

  Future<List<HomeworkAssignment>> listHomework({
    required RepositoryQuery query,
  });

  Future<HomeworkAssignment> generateHomework({
    required RepositoryQuery query,
    required GenerateHomeworkRequest request,
  });

  Future<HomeworkAssignment> publishHomework({
    required RepositoryQuery query,
    required String homeworkId,
  });

  Future<Map<String, dynamic>> exportHomework({
    required RepositoryQuery query,
    required String homeworkId,
  });

  Future<List<ReportCardRemark>> listReportRemarks({
    required RepositoryQuery query,
    String? studentId,
  });

  Future<ReportCardRemark> generateReportRemark({
    required RepositoryQuery query,
    required GenerateReportRemarkRequest request,
  });

  Future<ReportCardRemark> updateReportRemark({
    required RepositoryQuery query,
    required String remarkId,
    required String editedRemark,
  });

  Future<ReportCardRemark> publishReportRemark({
    required RepositoryQuery query,
    required String remarkId,
  });
}
