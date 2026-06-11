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

  test('generateQuestionPaper reuses bank items before AI', () async {
    final detail = await repository.generateQuestionPaper(
      query: query,
      request: const GenerateQuestionPaperRequest(
        academicYearLabel: '2025-26',
        className: 'Grade 8',
        sectionName: 'A',
        subjectName: 'Mathematics',
        chapters: ['Algebra'],
        difficulty: EduDifficulty.mixed,
        totalMarks: 50,
        examType: EduExamType.unitTest,
      ),
    );

    expect(detail.items.isNotEmpty, isTrue);
    expect(detail.paper.bankReuseCount, greaterThan(0));
    expect(detail.paper.aiGeneratedCount, greaterThan(0));
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
