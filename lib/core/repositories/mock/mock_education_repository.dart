import '../../../features/education/education_models.dart';
import '../interfaces/education_repository.dart';
import '../repository_query.dart';

class MockEducationRepository implements EducationRepository {
  MockEducationRepository() {
    _bank.addAll([
      const QuestionBankItem(
        id: 'bank_1',
        subjectName: 'Mathematics',
        chapter: 'Algebra',
        topic: 'Linear equations',
        difficulty: EduDifficulty.medium,
        questionType: EduQuestionType.mcq,
        marks: 2,
        questionText: 'Solve 2x + 4 = 10',
        answerText: 'x = 3',
        options: ['x = 2', 'x = 3', 'x = 4', 'x = 5'],
      ),
      const QuestionBankItem(
        id: 'bank_2',
        subjectName: 'Science',
        chapter: 'Physics',
        topic: 'Motion',
        difficulty: EduDifficulty.easy,
        questionType: EduQuestionType.shortAnswer,
        marks: 3,
        questionText: 'Define velocity.',
        answerText: 'Rate of change of displacement.',
      ),
    ]);
    _homework.addAll([
      HomeworkAssignment(
        id: 'hw_demo_1',
        title: '5 — Mathematics worksheet',
        className: '5',
        sectionName: 'A',
        subjectName: 'Mathematics',
        topic: 'Fractions',
        difficulty: EduDifficulty.medium,
        assignmentType: EduHomeworkType.practiceWorksheet,
        content: const [
          {'prompt': 'Add 1/2 + 1/4', 'answerHint': '3/4'},
        ],
        status: 'published',
      ),
    ]);
    _papers.add(
      QuestionPaperDetail(
        paper: const QuestionPaperSummary(
          id: 'paper_demo_1',
          title: '5 — Mathematics unit test',
          className: '5',
          sectionName: 'A',
          subjectName: 'Mathematics',
          examType: EduExamType.unitTest,
          totalMarks: 50,
          difficulty: EduDifficulty.medium,
          status: 'published',
        ),
        items: const [],
        blueprint: const {},
        answerKey: const [],
      ),
    );
  }

  final List<QuestionBankItem> _bank = [];
  final List<QuestionPaperDetail> _papers = [];
  final List<HomeworkAssignment> _homework = [];
  final List<ReportCardRemark> _remarks = [];
  int _id = 100;

  String _nextId(String prefix) {
    _id += 1;
    return '${prefix}_$_id';
  }

  @override
  Future<List<QuestionBankItem>> listQuestionBank({
    required RepositoryQuery query,
    String? subjectName,
    String? search,
  }) async {
    return _bank.where((item) {
      if (subjectName != null &&
          !item.subjectName.toLowerCase().contains(subjectName.toLowerCase())) {
        return false;
      }
      if (search != null &&
          !item.questionText.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Future<QuestionBankItem> createQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  }) async {
    final created = QuestionBankItem(
      id: _nextId('bank'),
      subjectName: item.subjectName,
      chapter: item.chapter,
      topic: item.topic,
      difficulty: item.difficulty,
      questionType: item.questionType,
      marks: item.marks,
      questionText: item.questionText,
      answerText: item.answerText,
      options: item.options,
    );
    _bank.add(created);
    return created;
  }

  @override
  Future<List<QuestionPaperSummary>> listQuestionPapers({
    required RepositoryQuery query,
  }) async =>
      _papers.map((d) => d.paper).toList(growable: false);

  @override
  Future<QuestionPaperDetail> generateQuestionPaper({
    required RepositoryQuery query,
    required GenerateQuestionPaperRequest request,
  }) async {
    final bankItems = _bank
        .where((b) => b.subjectName == request.subjectName)
        .take(2)
        .toList();
    final aiCount = request.totalMarks > 10 ? 2 : 1;
    final items = <QuestionPaperItem>[
      ...bankItems.asMap().entries.map(
            (e) => QuestionPaperItem(
              questionNumber: e.key + 1,
              questionType: e.value.questionType,
              marks: e.value.marks,
              questionText: e.value.questionText,
              answerText: e.value.answerText,
              options: e.value.options,
              source: 'bank',
            ),
          ),
      ...List.generate(
        aiCount,
        (i) => QuestionPaperItem(
          questionNumber: bankItems.length + i + 1,
          questionType: EduQuestionType.longAnswer,
          marks: 5,
          questionText:
              'AI generated: ${request.subjectName} — ${request.chapters.firstOrNull ?? "General"}',
          answerText: 'Sample model answer.',
          source: 'ai_generated',
        ),
      ),
    ];

    final paper = QuestionPaperSummary(
      id: _nextId('paper'),
      title:
          '${request.className} — ${request.subjectName} ${request.examType.name}',
      className: request.className,
      sectionName: request.sectionName,
      subjectName: request.subjectName,
      examType: request.examType,
      totalMarks: request.totalMarks,
      difficulty: request.difficulty,
      status: 'draft',
      bankReuseCount: bankItems.length,
      aiGeneratedCount: aiCount,
    );

    final detail = QuestionPaperDetail(
      paper: paper,
      items: items,
      blueprint: {
        'questionCount': items.length,
        'typeDistribution': {'mcq': 1, 'long_answer': aiCount},
      },
      answerKey: items
          .map((q) => {
                'questionNumber': q.questionNumber,
                'answer': q.answerText ?? '',
                'marks': q.marks,
              })
          .toList(),
    );
    _papers.add(detail);
    return detail;
  }

  @override
  Future<QuestionPaperDetail> getQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    return _papers.firstWhere((p) => p.paper.id == paperId);
  }

  @override
  Future<QuestionPaperSummary> publishQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final index = _papers.indexWhere((p) => p.paper.id == paperId);
    final current = _papers[index];
    final published = QuestionPaperSummary(
      id: current.paper.id,
      title: current.paper.title,
      className: current.paper.className,
      sectionName: current.paper.sectionName,
      subjectName: current.paper.subjectName,
      examType: current.paper.examType,
      totalMarks: current.paper.totalMarks,
      difficulty: current.paper.difficulty,
      status: 'published',
      bankReuseCount: current.paper.bankReuseCount,
      aiGeneratedCount: current.paper.aiGeneratedCount,
    );
    _papers[index] = QuestionPaperDetail(
      paper: published,
      items: current.items,
      blueprint: current.blueprint,
      answerKey: current.answerKey,
    );
    return published;
  }

  @override
  Future<Map<String, dynamic>> exportQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final detail = await getQuestionPaper(query: query, paperId: paperId);
    return {
      'title': detail.paper.title,
      'questions': detail.items.map((q) => q.questionText).toList(),
      'answerKey': detail.answerKey,
      'blueprint': detail.blueprint,
      'format': 'akshara-education-pdf-v1',
    };
  }

  @override
  Future<List<HomeworkAssignment>> listHomework({
    required RepositoryQuery query,
  }) async =>
      List<HomeworkAssignment>.unmodifiable(_homework);

  @override
  Future<HomeworkAssignment> generateHomework({
    required RepositoryQuery query,
    required GenerateHomeworkRequest request,
  }) async {
    final created = HomeworkAssignment(
      id: _nextId('hw'),
      title:
          '${request.className} — ${request.subjectName} ${request.assignmentType.name}',
      className: request.className,
      sectionName: request.sectionName,
      subjectName: request.subjectName,
      topic: request.topic,
      difficulty: request.difficulty,
      assignmentType: request.assignmentType,
      content: List.generate(
        5,
        (i) => {
          'prompt': 'Q${i + 1}: ${request.topic}',
          'answerHint': 'Sample answer ${i + 1}',
        },
      ),
      status: 'draft',
      dueDate: request.dueDate,
    );
    _homework.add(created);
    return created;
  }

  @override
  Future<HomeworkAssignment> publishHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    final index = _homework.indexWhere((h) => h.id == homeworkId);
    final current = _homework[index];
    final published = HomeworkAssignment(
      id: current.id,
      title: current.title,
      className: current.className,
      sectionName: current.sectionName,
      subjectName: current.subjectName,
      topic: current.topic,
      difficulty: current.difficulty,
      assignmentType: current.assignmentType,
      content: current.content,
      status: 'published',
      dueDate: current.dueDate,
    );
    _homework[index] = published;
    return published;
  }

  @override
  Future<Map<String, dynamic>> exportHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    final hw = _homework.firstWhere((h) => h.id == homeworkId);
    return {'title': hw.title, 'content': hw.content, 'format': 'akshara-education-pdf-v1'};
  }

  @override
  Future<List<ReportCardRemark>> listReportRemarks({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    return _remarks
        .where((r) => studentId == null || r.studentId == studentId)
        .toList(growable: false);
  }

  @override
  Future<ReportCardRemark> generateReportRemark({
    required RepositoryQuery query,
    required GenerateReportRemarkRequest request,
  }) async {
    final remark = ReportCardRemark(
      id: _nextId('remark'),
      studentId: request.studentId,
      academicYearLabel: request.academicYearLabel,
      remarkType: request.remarkType,
      language: request.language,
      displayRemark:
          'Generated ${request.remarkType.name} remark (${request.language.name}) for student.',
      generatedRemark:
          'Generated ${request.remarkType.name} remark (${request.language.name}) for student.',
      status: 'draft',
    );
    _remarks.add(remark);
    return remark;
  }

  @override
  Future<ReportCardRemark> updateReportRemark({
    required RepositoryQuery query,
    required String remarkId,
    required String editedRemark,
  }) async {
    final index = _remarks.indexWhere((r) => r.id == remarkId);
    final current = _remarks[index];
    final updated = ReportCardRemark(
      id: current.id,
      studentId: current.studentId,
      academicYearLabel: current.academicYearLabel,
      remarkType: current.remarkType,
      language: current.language,
      displayRemark: editedRemark,
      generatedRemark: current.generatedRemark,
      editedRemark: editedRemark,
      status: current.status,
    );
    _remarks[index] = updated;
    return updated;
  }

  @override
  Future<ReportCardRemark> publishReportRemark({
    required RepositoryQuery query,
    required String remarkId,
  }) async {
    final index = _remarks.indexWhere((r) => r.id == remarkId);
    final current = _remarks[index];
    final published = ReportCardRemark(
      id: current.id,
      studentId: current.studentId,
      academicYearLabel: current.academicYearLabel,
      remarkType: current.remarkType,
      language: current.language,
      displayRemark: current.displayRemark,
      generatedRemark: current.generatedRemark,
      editedRemark: current.editedRemark,
      status: 'published',
    );
    _remarks[index] = published;
    return published;
  }
}
