import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/api_exam_administration_repository.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/remote/exam_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/remote/exam_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('F4 exam API integration', () {
    test('ApiExamAdministrationRepository completes server-backed lifecycle', () async {
      ExamAdministrationStore.instance.reset();
      final store = ExamAdministrationStore.instance;
      store.ensureSeeded();

      final apiRepo = ApiExamAdministrationRepository(
        remote: ExamRemoteDataSource(
          createFakeDio((options) {
            final path = options.path;
            final method = options.method.toUpperCase();

            if (path == ExamApiPaths.base && method == 'POST') {
              final body = options.data as Map<String, dynamic>;
              return {
                'data': {
                  'id': 'exam_f4_chain',
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

            const examId = 'exam_f4_chain';
            if (path.endsWith('/schedule') && method == 'POST') {
              return {'data': _session(examId, 'scheduled')};
            }
            if (path.endsWith('/open-marks') && method == 'POST') {
              return {'data': _session(examId, 'marks_entry')};
            }
            if (path.endsWith('/process') && method == 'POST') {
              return {'data': _session(examId, 'processed')};
            }
            if (path.endsWith('/publish') && method == 'POST') {
              return {'data': {'examId': examId, 'publishedCount': 2}};
            }
            if (path.endsWith('/marks') && method == 'GET') {
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
                ],
              };
            }
            if (path.contains('/marks/') && method == 'PATCH') {
              final body = options.data as Map<String, dynamic>;
              return {
                'data': {
                  'id': 'exam_f4_chain_01',
                  'examId': examId,
                  'sisStudentId': 'SIS-STU-10430',
                  'studentName': 'Aarav Mehta',
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
                    'markEntryId': 'exam_f4_chain_01',
                    'sisStudentId': 'SIS-STU-10430',
                    'studentName': 'Aarav Mehta',
                    'examId': examId,
                    'examTitle': 'F4 Chain Exam',
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
        ),
      );

      final created = await apiRepo.createExam(
        query: _query,
        request: const CreateExamAdministrationRequest(
          title: 'F4 Chain Exam',
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
      expect(created.id, 'exam_f4_chain');

      await apiRepo.scheduleExam(query: _query, examId: created.id);
      await apiRepo.openMarksEntry(query: _query, examId: created.id);
      final marks = await apiRepo.listMarks(query: _query, examId: created.id);
      for (final mark in marks) {
        await apiRepo.updateMark(
          query: _query,
          request: UpdateExamMarkRequest(
            markEntryId: mark.id,
            marksObtained: 40,
          ),
        );
      }
      final processed =
          await apiRepo.processResults(query: _query, examId: created.id);
      expect(processed.phase, ExamLifecyclePhase.processed);

      final published =
          await apiRepo.publishResults(query: _query, examId: created.id);
      expect(published, 2);

      final results = await apiRepo.listPublishedResultsForStudent(
        query: _query,
        sisStudentId: 'SIS-STU-10430',
      );
      expect(results, isNotEmpty);
      expect(store.allExams(), isNotEmpty);
    });
  });
}

Map<String, dynamic> _session(String examId, String phase) => {
      'id': examId,
      'title': 'F4 Chain Exam',
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
