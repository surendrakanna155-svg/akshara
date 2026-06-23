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
