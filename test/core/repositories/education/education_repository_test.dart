import 'package:akshara_erp/core/repositories/mock/mock_education_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery(tenantId: 'tenant', schoolId: 'school');
  late MockEducationRepository repository;

  setUp(() {
    repository = MockEducationRepository();
  });

  const mathPaper = GenerateQuestionPaperRequest(
    academicYearLabel: '2025-26',
    className: 'Grade 8',
    sectionName: 'A',
    subjectName: 'Mathematics',
    chapters: ['Algebra'],
    difficulty: EduDifficulty.mixed,
    totalMarks: 50,
    examType: EduExamType.unitTest,
  );

  test('generateQuestionPaper reuses bank items before AI', () async {
    final detail = await repository.generateQuestionPaper(
      query: query,
      request: mathPaper,
    );

    expect(detail.items.isNotEmpty, isTrue);
    expect(detail.paper.bankReuseCount, greaterThan(0));
    expect(detail.paper.aiGeneratedCount, greaterThan(0));
    expect(detail.aiCandidateCount, greaterThan(0));
    expect(detail.paper.reviewStatus, EduPaperReviewStatus.draft);
    // AI items arrive as candidates pending moderation, not auto-included.
    expect(detail.pendingAiItems, isNotEmpty);
  });

  test('AI gap-fill off reports unfilled gaps instead of fabricating', () async {
    final detail = await repository.generateQuestionPaper(
      query: query,
      request: const GenerateQuestionPaperRequest(
        academicYearLabel: '2025-26',
        className: 'Grade 8',
        subjectName: 'Mathematics',
        chapters: ['Algebra'],
        difficulty: EduDifficulty.mixed,
        totalMarks: 50,
        examType: EduExamType.unitTest,
        allowAiGapFill: false,
      ),
    );

    expect(detail.aiCandidateCount, 0);
    expect(detail.pendingAiItems, isEmpty);
    expect(detail.unfilledGapCount, greaterThan(0));
    expect(detail.gaps, isNotEmpty);
  });

  test('publish is blocked while AI candidates await moderation', () async {
    final detail = await repository.generateQuestionPaper(
      query: query,
      request: mathPaper,
    );

    expect(
      () => repository.publishQuestionPaper(query: query, paperId: detail.paper.id),
      throwsA(isA<StateError>()),
    );
  });

  test('moderation + governance lifecycle reaches published', () async {
    final detail = await repository.generateQuestionPaper(
      query: query,
      request: mathPaper,
    );
    final paperId = detail.paper.id;

    // Approve every pending AI candidate.
    for (final item in detail.pendingAiItems) {
      final moderated = await repository.moderatePaperItem(
        query: query,
        paperId: paperId,
        itemId: item.id!,
        decision: 'approved',
      );
      expect(moderated.reviewStatus, 'approved');
    }

    final submitted =
        await repository.submitQuestionPaper(query: query, paperId: paperId);
    expect(submitted.reviewStatus, EduPaperReviewStatus.submitted);

    final reviews = await repository.listPaperReviews(query: query, paperId: paperId);
    expect(reviews, isNotEmpty);

    final approved = await repository.reviewQuestionPaper(
      query: query,
      paperId: paperId,
      decision: 'approved',
    );
    expect(approved.reviewStatus, EduPaperReviewStatus.approved);

    final published =
        await repository.publishQuestionPaper(query: query, paperId: paperId);
    expect(published.reviewStatus, EduPaperReviewStatus.published);
    expect(published.status, 'published');
  });

  test('A: editing a question in an approved paper resets it to draft', () async {
    final detail = await repository.generateQuestionPaper(query: query, request: mathPaper);
    final paperId = detail.paper.id;
    for (final item in detail.pendingAiItems) {
      await repository.moderatePaperItem(
        query: query, paperId: paperId, itemId: item.id!, decision: 'approved',
      );
    }
    await repository.submitQuestionPaper(query: query, paperId: paperId);
    await repository.reviewQuestionPaper(query: query, paperId: paperId, decision: 'approved');

    final fresh = await repository.getQuestionPaper(query: query, paperId: paperId);
    expect(fresh.paper.reviewStatus, EduPaperReviewStatus.approved);
    final target = fresh.items.first;

    final edited = await repository.updatePaperItem(
      query: query,
      paperId: paperId,
      itemId: target.id!,
      questionText: 'Corrected question text',
    );
    expect(edited.questionText, 'Corrected question text');

    final after = await repository.getQuestionPaper(query: query, paperId: paperId);
    expect(after.paper.reviewStatus, EduPaperReviewStatus.draft);
  });

  test('C: updateQuestionBankItem persists the edit', () async {
    final bank = await repository.listQuestionBank(query: query);
    final original = bank.first;
    final edited = QuestionBankItem(
      id: original.id,
      subjectName: original.subjectName,
      chapter: original.chapter,
      topic: original.topic,
      difficulty: original.difficulty,
      questionType: original.questionType,
      marks: 5,
      questionText: 'Edited bank question',
      answerText: original.answerText,
      options: original.options,
    );
    final result = await repository.updateQuestionBankItem(query: query, item: edited);
    expect(result.questionText, 'Edited bank question');
    expect(result.marks, 5);

    final reread = await repository.listQuestionBank(query: query);
    expect(reread.firstWhere((b) => b.id == original.id).questionText, 'Edited bank question');
  });

  test('E: only an approved AI candidate promotes to the bank', () async {
    final detail = await repository.generateQuestionPaper(query: query, request: mathPaper);
    final paperId = detail.paper.id;
    final candidate = detail.pendingAiItems.first;

    // Pending → rejected by the promote gate.
    expect(
      () => repository.promotePaperItemToBank(
        query: query, paperId: paperId, itemId: candidate.id!,
      ),
      throwsA(isA<StateError>()),
    );

    await repository.moderatePaperItem(
      query: query, paperId: paperId, itemId: candidate.id!, decision: 'approved',
    );
    final bankBefore = (await repository.listQuestionBank(query: query)).length;
    final promoted = await repository.promotePaperItemToBank(
      query: query, paperId: paperId, itemId: candidate.id!, chapter: 'Algebra',
    );
    expect(promoted.chapter, 'Algebra');
    final bankAfter = (await repository.listQuestionBank(query: query)).length;
    expect(bankAfter, bankBefore + 1);
  });

  test('importQuestionBank adds new rows and skips duplicates', () async {
    final result = await repository.importQuestionBank(
      query: query,
      items: const [
        QuestionBankItem(
          id: '',
          subjectName: 'Mathematics',
          chapter: 'Algebra',
          topic: 'Linear equations',
          difficulty: EduDifficulty.medium,
          questionType: EduQuestionType.mcq,
          marks: 2,
          questionText: 'Solve 2x + 4 = 10', // duplicate of seeded bank_1
        ),
        QuestionBankItem(
          id: '',
          subjectName: 'Mathematics',
          chapter: 'Real Numbers',
          topic: 'HCF',
          difficulty: EduDifficulty.easy,
          questionType: EduQuestionType.mcq,
          marks: 1,
          questionText: 'What is the HCF of 12 and 18?',
        ),
      ],
    );

    expect(result.imported, 1);
    expect(result.skippedDuplicates, 1);
    final bank = await repository.listQuestionBank(query: query);
    expect(bank.any((q) => q.questionText == 'What is the HCF of 12 and 18?'), isTrue);
  });

  test('generateHomework creates draft assignment', () async {
    final hw = await repository.generateHomework(
      query: query,
      request: const GenerateHomeworkRequest(
        academicYearLabel: '2025-26',
        className: 'Grade 8',
        subjectName: 'Science',
        topic: 'Motion',
        difficulty: EduDifficulty.medium,
        assignmentType: EduHomeworkType.practiceWorksheet,
      ),
    );

    expect(hw.status, 'draft');
    expect(hw.content.length, 5);
  });

  test('generateReportRemark supports multilingual output', () async {
    final remark = await repository.generateReportRemark(
      query: query,
      request: const GenerateReportRemarkRequest(
        studentId: 'student_1',
        academicYearLabel: '2025-26',
        remarkType: EduRemarkType.principal,
        language: EduRemarkLanguage.telugu,
        inputs: ReportRemarkInputs(attendancePercent: 90),
      ),
    );

    expect(remark.language, EduRemarkLanguage.telugu);
    expect(remark.displayRemark.isNotEmpty, isTrue);
  });
}
