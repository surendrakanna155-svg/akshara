import '../../../../features/education/education_models.dart';
import '../../interfaces/education_repository.dart';
import '../../repository_query.dart';
import 'mapper/education_mapper.dart';
import 'remote/education_remote_datasource.dart';

class ApiEducationRepository implements EducationRepository {
  ApiEducationRepository({required EducationRemoteDataSource remote}) : _remote = remote;

  final EducationRemoteDataSource _remote;

  @override
  Future<List<QuestionBankItem>> listQuestionBank({
    required RepositoryQuery query,
    String? subjectName,
    String? search,
  }) async {
    final rows = await _remote.fetchQuestionBank(
      query: query,
      subjectName: subjectName,
      search: search,
    );
    return rows.map(EducationMapper.questionBankFromApi).toList();
  }

  @override
  Future<QuestionBankItem> createQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  }) async {
    final row = await _remote.createQuestionBankItem(query: query, item: item);
    return EducationMapper.questionBankFromApi(row);
  }

  @override
  Future<QuestionImportResult> importQuestionBank({
    required RepositoryQuery query,
    required List<QuestionBankItem> items,
  }) async {
    final data = await _remote.importQuestionBank(query: query, items: items);
    return QuestionImportResult(
      imported: (data['imported'] as num?)?.toInt() ?? 0,
      skippedDuplicates: (data['skippedDuplicates'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<QuestionBankItem> updateQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  }) async {
    final row = await _remote.updateQuestionBankItem(query: query, item: item);
    return EducationMapper.questionBankFromApi(row);
  }

  @override
  Future<List<QuestionPaperSummary>> listQuestionPapers({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchQuestionPapers(query: query);
    return rows.map(EducationMapper.paperSummaryFromApi).toList();
  }

  @override
  Future<QuestionPaperDetail> generateQuestionPaper({
    required RepositoryQuery query,
    required GenerateQuestionPaperRequest request,
  }) async {
    final data = await _remote.generateQuestionPaper(query: query, request: request);
    return _paperDetailFromGenerateResponse(data);
  }

  @override
  Future<QuestionPaperDetail> getQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final data = await _remote.fetchQuestionPaper(query: query, paperId: paperId);
    return _paperDetailFromGetResponse(data);
  }

  @override
  Future<QuestionPaperSummary> publishQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final row = await _remote.publishQuestionPaper(query: query, paperId: paperId);
    return EducationMapper.paperSummaryFromApi(row);
  }

  @override
  Future<QuestionPaperSummary> submitQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final data = await _remote.submitQuestionPaper(query: query, paperId: paperId);
    return EducationMapper.paperSummaryFromApi(
      Map<String, dynamic>.from(data['paper'] as Map),
    );
  }

  @override
  Future<QuestionPaperSummary> reviewQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
    required String decision,
    String? comments,
  }) async {
    final data = await _remote.reviewQuestionPaper(
      query: query,
      paperId: paperId,
      decision: decision,
      comments: comments,
    );
    return EducationMapper.paperSummaryFromApi(
      Map<String, dynamic>.from(data['paper'] as Map),
    );
  }

  @override
  Future<List<PaperReview>> listPaperReviews({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final rows = await _remote.fetchPaperReviews(query: query, paperId: paperId);
    return rows.map(EducationMapper.paperReviewFromApi).toList();
  }

  @override
  Future<QuestionPaperItem> moderatePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    required String decision,
  }) async {
    final row = await _remote.moderatePaperItem(
      query: query,
      paperId: paperId,
      itemId: itemId,
      decision: decision,
    );
    return EducationMapper.paperItemFromApi(row);
  }

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
  }) async {
    final row = await _remote.updatePaperItem(
      query: query,
      paperId: paperId,
      itemId: itemId,
      questionType: questionType,
      marks: marks,
      questionText: questionText,
      answerText: answerText,
      options: options,
    );
    return EducationMapper.paperItemFromApi(row);
  }

  @override
  Future<QuestionPaperItem> regeneratePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    String? chapter,
  }) async {
    final row = await _remote.regeneratePaperItem(
      query: query,
      paperId: paperId,
      itemId: itemId,
      chapter: chapter,
    );
    return EducationMapper.paperItemFromApi(row);
  }

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
  }) async {
    final row = await _remote.promotePaperItemToBank(
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
    return EducationMapper.questionBankFromApi(row);
  }

  @override
  Future<Map<String, dynamic>> exportQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) =>
      _remote.exportQuestionPaper(query: query, paperId: paperId);

  @override
  Future<List<HomeworkAssignment>> listHomework({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchHomework(query: query);
    return rows.map(EducationMapper.homeworkFromApi).toList();
  }

  @override
  Future<HomeworkAssignment> generateHomework({
    required RepositoryQuery query,
    required GenerateHomeworkRequest request,
  }) async {
    final row = await _remote.generateHomework(query: query, request: request);
    return EducationMapper.homeworkFromApi(row);
  }

  @override
  Future<HomeworkAssignment> publishHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    final row = await _remote.publishHomework(query: query, homeworkId: homeworkId);
    return EducationMapper.homeworkFromApi(row);
  }

  @override
  Future<Map<String, dynamic>> exportHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) =>
      _remote.exportHomework(query: query, homeworkId: homeworkId);

  @override
  Future<List<ReportCardRemark>> listReportRemarks({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    final rows = await _remote.fetchReportRemarks(query: query, studentId: studentId);
    return rows.map(EducationMapper.remarkFromApi).toList();
  }

  @override
  Future<ReportCardRemark> generateReportRemark({
    required RepositoryQuery query,
    required GenerateReportRemarkRequest request,
  }) async {
    final row = await _remote.generateReportRemark(query: query, request: request);
    return EducationMapper.remarkFromApi(row);
  }

  @override
  Future<ReportCardRemark> updateReportRemark({
    required RepositoryQuery query,
    required String remarkId,
    required String editedRemark,
  }) async {
    final row = await _remote.updateReportRemark(
      query: query,
      remarkId: remarkId,
      editedRemark: editedRemark,
    );
    return EducationMapper.remarkFromApi(row);
  }

  @override
  Future<ReportCardRemark> publishReportRemark({
    required RepositoryQuery query,
    required String remarkId,
  }) async {
    final row = await _remote.publishReportRemark(query: query, remarkId: remarkId);
    return EducationMapper.remarkFromApi(row);
  }

  QuestionPaperDetail _paperDetailFromGenerateResponse(Map<String, dynamic> data) {
    final paperJson = Map<String, dynamic>.from(data['paper'] as Map);
    final paper = EducationMapper.paperSummaryFromApi(paperJson);
    final summary = QuestionPaperSummary(
      id: paper.id,
      title: paper.title,
      className: paper.className,
      sectionName: paper.sectionName,
      subjectName: paper.subjectName,
      examType: paper.examType,
      totalMarks: paper.totalMarks,
      difficulty: paper.difficulty,
      status: paper.status,
      reviewStatus: paper.reviewStatus,
      programTrack: paper.programTrack,
      bankReuseCount: data['bankReuseCount'] as int?,
      aiGeneratedCount: data['aiGeneratedCount'] as int?,
    );
    final items = (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(EducationMapper.paperItemFromApi)
        .toList();
    final gaps = (data['gaps'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(EducationMapper.paperGapFromApi)
        .toList();
    return QuestionPaperDetail(
      paper: summary,
      items: items,
      blueprint: Map<String, dynamic>.from(paperJson['blueprint'] as Map? ?? const {}),
      answerKey: paperJson['answerKey'] is List
          ? List<Map<String, dynamic>>.from(
              (paperJson['answerKey'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : const [],
      aiCandidateCount: data['aiCandidateCount'] as int? ?? 0,
      unfilledGapCount: data['unfilledGapCount'] as int? ?? 0,
      gaps: gaps,
    );
  }

  QuestionPaperDetail _paperDetailFromGetResponse(Map<String, dynamic> data) {
    final paper = EducationMapper.paperSummaryFromApi(
      Map<String, dynamic>.from(data['paper'] as Map),
    );
    final items = (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(EducationMapper.paperItemFromApi)
        .toList();
    return QuestionPaperDetail(
      paper: paper,
      items: items,
      blueprint: Map<String, dynamic>.from(
        (data['paper'] as Map)['blueprint'] as Map? ?? const {},
      ),
      answerKey: (data['paper'] as Map)['answerKey'] is List
          ? List<Map<String, dynamic>>.from(
              ((data['paper'] as Map)['answerKey'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : const [],
    );
  }
}
