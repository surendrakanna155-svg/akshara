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
  final String status;
  final int? bankReuseCount;
  final int? aiGeneratedCount;
}

class QuestionPaperDetail {
  const QuestionPaperDetail({
    required this.paper,
    required this.items,
    required this.blueprint,
    required this.answerKey,
  });

  final QuestionPaperSummary paper;
  final List<QuestionPaperItem> items;
  final Map<String, dynamic> blueprint;
  final List<Map<String, dynamic>> answerKey;
}

class QuestionPaperItem {
  const QuestionPaperItem({
    required this.questionNumber,
    required this.questionType,
    required this.marks,
    required this.questionText,
    this.answerText,
    this.options = const [],
    this.source = 'bank',
  });

  final int questionNumber;
  final EduQuestionType questionType;
  final int marks;
  final String questionText;
  final String? answerText;
  final List<String> options;
  final String source;
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
  });

  final String academicYearLabel;
  final String className;
  final String? sectionName;
  final String subjectName;
  final List<String> chapters;
  final EduDifficulty difficulty;
  final int totalMarks;
  final EduExamType examType;
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
