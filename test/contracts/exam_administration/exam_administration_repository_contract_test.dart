import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/api_exam_administration_repository.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/mapper/exam_mapper.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/remote/exam_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/remote/exam_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_exam_administration_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;
  const mapper = ExamMapper();

  setUp(() {
    ExamAdministrationStore.instance.reset();
  });

  Future<void> runLifecycleContract(
    dynamic repo, {
    required String label,
  }) async {
    final created = await repo.createExam(
      query: query,
      request: const CreateExamAdministrationRequest(
        title: 'Half-Yearly Mathematics',
        subject: 'Mathematics',
        grade: '8',
        section: 'B',
        termLabel: 'Term 2',
        dateLabel: '20 Jun 2026',
        timeLabel: '9:00 AM',
        venueLabel: 'Room 8B',
        syllabusLabel: 'Algebra',
        maxMarks: 80,
        examType: EduExamType.halfYearly,
      ),
    );
    expect(created.phase, ExamLifecyclePhase.draft, reason: label);

    final scheduled =
        await repo.scheduleExam(query: query, examId: created.id);
    expect(scheduled.phase, ExamLifecyclePhase.scheduled, reason: label);

    final marksOpen =
        await repo.openMarksEntry(query: query, examId: created.id);
    expect(marksOpen.phase, ExamLifecyclePhase.marksEntry, reason: label);

    final marks = await repo.listMarks(query: query, examId: created.id);
    expect(marks, isNotEmpty, reason: label);

    for (final mark in marks) {
      await repo.updateMark(
        query: query,
        request: UpdateExamMarkRequest(
          markEntryId: mark.id,
          marksObtained: 40,
        ),
      );
    }

    final processed =
        await repo.processResults(query: query, examId: created.id);
    expect(processed.phase, ExamLifecyclePhase.processed, reason: label);

    final publishedCount =
        await repo.publishResults(query: query, examId: created.id);
    expect(publishedCount, marks.length, reason: label);

    final studentId = marks.first.sisStudentId;
    final published = await repo.listPublishedResultsForStudent(
      query: query,
      sisStudentId: studentId,
    );
    expect(published.any((r) => r.examId == created.id), isTrue, reason: label);
  }

  group('Exam administration repository contract', () {
    test('mock listExams returns seeded sessions after ensure', () async {
      final repo = MockExamAdministrationRepository();
      final exams = await repo.listExams(query: query);
      expect(exams, isNotEmpty);
      expect(exams.any((e) => e.id == 'exam_math_8a'), isTrue);
    });

    test('mock create → publish lifecycle', () async {
      await runLifecycleContract(MockExamAdministrationRepository(), label: 'mock');
    });

    test('API fake-Dio parity with mock lifecycle', () async {
      ExamAdministrationStore.instance.ensureSeeded();
      final seededExams = ExamAdministrationStore.instance.allExams();
      final remote = ExamRemoteDataSource(
        createFakeDio((options) {
          final path = options.path;
          final method = options.method.toUpperCase();

          if (path == ExamApiPaths.base && method == 'GET') {
            return {
              'data': [
                for (final exam in seededExams)
                  {
                    'id': exam.id,
                    'title': exam.title,
                    'subject': exam.subject,
                    'grade': exam.grade,
                    'section': exam.section,
                    'termLabel': exam.termLabel,
                    'dateLabel': exam.dateLabel,
                    'timeLabel': exam.timeLabel,
                    'venueLabel': exam.venueLabel,
                    'syllabusLabel': exam.syllabusLabel,
                    'maxMarks': exam.maxMarks,
                    'phase': exam.phase.name == 'marksEntry'
                        ? 'marks_entry'
                        : exam.phase.name,
                    'examType': 'half_yearly',
                    'coordinatorVerified': exam.coordinatorVerified,
                    'rejectionComment': exam.rejectionComment,
                  },
              ],
            };
          }

          if (path == ExamApiPaths.base && method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            return {
              'data': {
                'id': 'exam_api_1',
                'title': body['title'],
                'subject': body['subject'],
                'grade': body['grade'],
                'section': body['section'],
                'termLabel': body['termLabel'],
                'dateLabel': body['dateLabel'],
                'timeLabel': body['timeLabel'],
                'venueLabel': body['venueLabel'],
                'syllabusLabel': body['syllabusLabel'],
                'maxMarks': body['maxMarks'],
                'phase': 'draft',
                'examType': body['examType'],
              },
            };
          }

          final examIdMatch = RegExp(r'/academics/exams/([^/]+)').firstMatch(path);
          final examId = examIdMatch?.group(1);

          if (examId != null && path.endsWith('/schedule') && method == 'POST') {
            return {'data': _phasePayload(examId, 'scheduled')};
          }
          if (examId != null && path.endsWith('/open-marks') && method == 'POST') {
            return {'data': _phasePayload(examId, 'marks_entry')};
          }
          if (examId != null && path.endsWith('/process') && method == 'POST') {
            return {'data': _phasePayload(examId, 'processed')};
          }
          if (examId != null && path.endsWith('/publish') && method == 'POST') {
            return {'data': {'examId': examId, 'publishedCount': 3}};
          }
          if (examId != null && path.endsWith('/marks') && method == 'GET') {
            return {
              'data': [
                {
                  'id': '${examId}_01',
                  'examId': examId,
                  'sisStudentId': 'SIS-STU-10430',
                  'studentName': 'Aarav Mehta',
                  'rollNo': '01',
                  'marksObtained': null,
                  'published': false,
                  'maxMarks': 80,
                },
                {
                  'id': '${examId}_02',
                  'examId': examId,
                  'sisStudentId': 'SIS-STU-10431',
                  'studentName': 'Priya Sharma',
                  'rollNo': '02',
                  'marksObtained': null,
                  'published': false,
                  'maxMarks': 80,
                },
                {
                  'id': '${examId}_03',
                  'examId': examId,
                  'sisStudentId': 'SIS-STU-10432',
                  'studentName': 'Rohan Das',
                  'rollNo': '03',
                  'marksObtained': null,
                  'published': false,
                  'maxMarks': 80,
                },
              ],
            };
          }

          final markMatch =
              RegExp(r'/academics/exams/marks/([^/]+)').firstMatch(path);
          if (markMatch != null && method == 'PATCH') {
            final markId = markMatch.group(1)!;
            final body = options.data as Map<String, dynamic>;
            return {
              'data': {
                'id': markId,
                'examId': markId.split('_').first,
                'sisStudentId': 'SIS-STU-10430',
                'studentName': 'Student',
                'rollNo': '01',
                'marksObtained': body['marksObtained'],
                'published': false,
                'maxMarks': 80,
              },
            };
          }

          if (path.contains('/published') && method == 'GET') {
            return {
              'data': [
                {
                  'markEntryId': 'exam_api_1_01',
                  'sisStudentId': 'SIS-STU-10430',
                  'studentName': 'Aarav Mehta',
                  'examId': 'exam_api_1',
                  'examTitle': 'Half-Yearly Mathematics',
                  'termLabel': 'Term 2',
                  'dateLabel': '20 Jun 2026',
                  'scoreObtained': 40,
                  'maxScore': 80,
                  'grade': 'B',
                  'subject': 'Mathematics',
                },
              ],
            };
          }

          return {'data': {}};
        }),
        mapper: mapper,
      );

      final apiRepo = ApiExamAdministrationRepository(remote: remote);
      await runLifecycleContract(apiRepo, label: 'api');
    });

    test('getExam returns null for unknown id', () async {
      final repo = MockExamAdministrationRepository();
      final exam = await repo.getExam(query: query, examId: 'missing');
      expect(exam, isNull);
    });
  });
}

Map<String, dynamic> _phasePayload(String examId, String phase) => {
      'id': examId,
      'title': 'Half-Yearly Mathematics',
      'subject': 'Mathematics',
      'grade': '8',
      'section': 'B',
      'termLabel': 'Term 2',
      'dateLabel': '20 Jun 2026',
      'timeLabel': '9:00 AM',
      'venueLabel': 'Room 8B',
      'syllabusLabel': 'Algebra',
      'maxMarks': 80,
      'phase': phase,
      'examType': 'half_yearly',
    };
