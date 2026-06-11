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
