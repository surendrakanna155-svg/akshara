import '../../../../features/education/education_models.dart';
import '../../interfaces/education_repository.dart';
import '../../repository_query.dart';
import 'api_education_repository.dart';

class HybridEducationRepository implements EducationRepository {
  HybridEducationRepository({required ApiEducationRepository api}) : _api = api;

  final ApiEducationRepository _api;

  @override
  Future<List<QuestionBankItem>> listQuestionBank({
    required RepositoryQuery query,
    String? subjectName,
    String? search,
  }) =>
      _api.listQuestionBank(query: query, subjectName: subjectName, search: search);

  @override
  Future<QuestionBankItem> createQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  }) =>
      _api.createQuestionBankItem(query: query, item: item);

  @override
  Future<QuestionImportResult> importQuestionBank({
    required RepositoryQuery query,
    required List<QuestionBankItem> items,
  }) =>
      _api.importQuestionBank(query: query, items: items);

  @override
  Future<QuestionBankItem> updateQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  }) =>
      _api.updateQuestionBankItem(query: query, item: item);

  @override
  Future<List<QuestionPaperSummary>> listQuestionPapers({
    required RepositoryQuery query,
  }) =>
      _api.listQuestionPapers(query: query);

  @override
  Future<QuestionPaperDetail> generateQuestionPaper({
    required RepositoryQuery query,
    required GenerateQuestionPaperRequest request,
  }) =>
      _api.generateQuestionPaper(query: query, request: request);

  @override
  Future<QuestionPaperDetail> getQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) =>
      _api.getQuestionPaper(query: query, paperId: paperId);

  @override
  Future<QuestionPaperSummary> publishQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) =>
      _api.publishQuestionPaper(query: query, paperId: paperId);

  @override
  Future<QuestionPaperSummary> submitQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) =>
      _api.submitQuestionPaper(query: query, paperId: paperId);

  @override
  Future<QuestionPaperSummary> reviewQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
    required String decision,
    String? comments,
  }) =>
      _api.reviewQuestionPaper(
        query: query,
        paperId: paperId,
        decision: decision,
        comments: comments,
      );

  @override
  Future<List<PaperReview>> listPaperReviews({
    required RepositoryQuery query,
    required String paperId,
  }) =>
      _api.listPaperReviews(query: query, paperId: paperId);

  @override
  Future<QuestionPaperItem> moderatePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    required String decision,
  }) =>
      _api.moderatePaperItem(
        query: query,
        paperId: paperId,
        itemId: itemId,
        decision: decision,
      );

  @override
  Future<QuestionPaperItem> updatePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    EduQuestionType? questionType,
    int? marks,
    String? questionText,
    String? answerText,
    List<String>? options,
  }) =>
      _api.updatePaperItem(
        query: query,
        paperId: paperId,
        itemId: itemId,
        questionType: questionType,
        marks: marks,
        questionText: questionText,
        answerText: answerText,
        options: options,
      );

  @override
  Future<QuestionPaperItem> regeneratePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    String? chapter,
  }) =>
      _api.regeneratePaperItem(
        query: query,
        paperId: paperId,
        itemId: itemId,
        chapter: chapter,
      );

  @override
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
  }) =>
      _api.promotePaperItemToBank(
        query: query,
        paperId: paperId,
        itemId: itemId,
        chapter: chapter,
        topic: topic,
        difficulty: difficulty,
        cognitiveLevel: cognitiveLevel,
        syllabusChapterId: syllabusChapterId,
        learningOutcome: learningOutcome,
      );

  @override
  Future<Map<String, dynamic>> exportQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) =>
      _api.exportQuestionPaper(query: query, paperId: paperId);

  @override
  Future<List<HomeworkAssignment>> listHomework({
    required RepositoryQuery query,
  }) =>
      _api.listHomework(query: query);

  @override
  Future<HomeworkAssignment> generateHomework({
    required RepositoryQuery query,
    required GenerateHomeworkRequest request,
  }) =>
      _api.generateHomework(query: query, request: request);

  @override
  Future<HomeworkAssignment> publishHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) =>
      _api.publishHomework(query: query, homeworkId: homeworkId);

  @override
  Future<Map<String, dynamic>> exportHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) =>
      _api.exportHomework(query: query, homeworkId: homeworkId);

  @override
  Future<List<ReportCardRemark>> listReportRemarks({
    required RepositoryQuery query,
    String? studentId,
  }) =>
      _api.listReportRemarks(query: query, studentId: studentId);

  @override
  Future<ReportCardRemark> generateReportRemark({
    required RepositoryQuery query,
    required GenerateReportRemarkRequest request,
  }) =>
      _api.generateReportRemark(query: query, request: request);

  @override
  Future<ReportCardRemark> updateReportRemark({
    required RepositoryQuery query,
    required String remarkId,
    required String editedRemark,
  }) =>
      _api.updateReportRemark(
        query: query,
        remarkId: remarkId,
        editedRemark: editedRemark,
      );

  @override
  Future<ReportCardRemark> publishReportRemark({
    required RepositoryQuery query,
    required String remarkId,
  }) =>
      _api.publishReportRemark(query: query, remarkId: remarkId);
}
