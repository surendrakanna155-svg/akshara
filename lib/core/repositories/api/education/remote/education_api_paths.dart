abstract final class EducationApiPaths {
  static const String questionBank = '/education/question-bank';
  static const String questionBankImport = '/education/question-bank/import';
  static const String questionBankExport = '/education/question-bank/export';
  static const String questionPapers = '/education/question-papers';
  static const String questionPapersGenerate = '/education/question-papers/generate';
  static String questionPaper(String id) => '$questionPapers/$id';
  static String questionPaperPublish(String id) => '$questionPapers/$id/publish';
  static String questionPaperExport(String id) => '$questionPapers/$id/export';
  static const String homework = '/education/homework';
  static const String homeworkGenerate = '/education/homework/generate';
  static String homeworkItem(String id) => '$homework/$id';
  static String homeworkPublish(String id) => '$homework/$id/publish';
  static String homeworkExport(String id) => '$homework/$id/export';
  static const String reportRemarks = '/education/report-remarks';
  static const String reportRemarksGenerate = '/education/report-remarks/generate';
  static String reportRemark(String id) => '$reportRemarks/$id';
  static String reportRemarkPublish(String id) => '$reportRemarks/$id/publish';
}
