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

          // EXM-2 — marks-entry progress board.
          if (path == ExamApiPaths.progress && method == 'GET') {
            return {
              'data': [
                {
                  'examId': 'exam_api_1',
                  'title': 'Half-Yearly Mathematics',
                  'subject': 'Mathematics',
                  'grade': '8',
                  'sectionName': 'B',
                  'enteredCount': 2,
                  'totalCount': 3,
                  'pending': 1,
                },
              ],
            };
          }

          // EXM-1 — fast bulk marks save for one exam.
          if (examId != null &&
              path.endsWith('/marks/batch') &&
              method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            final entries = (body['entries'] as List).cast<Map<String, dynamic>>();
            return {
              'data': {
                'examId': examId,
                'updated': [
                  for (final e in entries)
                    {
                      'id': e['id'],
                      'examId': examId,
                      'sisStudentId': 'SIS-STU-10430',
                      'studentName': 'Student',
                      'rollNo': '01',
                      'marksObtained': e['marksObtained'],
                      'published': false,
                      'status': e['status'],
                      'maxMarks': 80,
                    },
                ],
                'failed': <Map<String, dynamic>>[],
              },
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

    // EXM-1 — fast bulk marks save.
    test('mock bulk save persists present rows + skips published (partial)',
        () async {
      final repo = MockExamAdministrationRepository();
      final marks = await repo.listMarks(query: query, examId: 'exam_math_8a');
      final open = marks.firstWhere((m) => m.marksObtained == null);

      final result = await repo.bulkUpdateMarks(
        query: query,
        request: BulkUpdateExamMarksRequest(
          examId: 'exam_math_8a',
          entries: [
            BulkExamMarkEntry(markEntryId: open.id, marksObtained: 33),
            // Missing row → reported, not fatal.
            const BulkExamMarkEntry(markEntryId: 'nope', marksObtained: 10),
          ],
        ),
      );
      expect(result.savedCount, 1);
      expect(result.failedCount, 1);
      expect(result.failed.first.markEntryId, 'nope');

      final refreshed =
          await repo.listMarks(query: query, examId: 'exam_math_8a');
      expect(refreshed.firstWhere((m) => m.id == open.id).marksObtained, 33);
    });

    // EXM-2 — marks-entry progress board.
    test('mock progress lists marks_entry exams with entered/total/pending',
        () async {
      final repo = MockExamAdministrationRepository();
      final rows = await repo.listMarksEntryProgress(query: query);
      // Seeded exam_math_8a is in marks_entry with one open slot.
      final math = rows.firstWhere((r) => r.examId == 'exam_math_8a');
      expect(math.totalCount, greaterThan(0));
      expect(math.pending, greaterThanOrEqualTo(1));
      expect(math.enteredCount, math.totalCount - math.pending);
    });

    test('API bulk save parses { updated, failed }', () async {
      final remote = ExamRemoteDataSource(
        createFakeDio((options) {
          if (options.path.endsWith('/marks/batch')) {
            final body = options.data as Map<String, dynamic>;
            final entries =
                (body['entries'] as List).cast<Map<String, dynamic>>();
            return {
              'data': {
                'examId': 'exam_api_1',
                'updated': [
                  for (final e in entries)
                    {
                      'id': e['id'],
                      'examId': 'exam_api_1',
                      'sisStudentId': 'SIS',
                      'studentName': 'S',
                      'rollNo': '01',
                      'marksObtained': e['marksObtained'],
                      'published': false,
                      'status': e['status'],
                      'maxMarks': 80,
                    },
                ],
                'failed': [
                  {'id': 'bad-1', 'reason': 'already published'},
                ],
              },
            };
          }
          return {'data': {}};
        }),
        mapper: mapper,
      );
      final apiRepo = ApiExamAdministrationRepository(remote: remote);
      final result = await apiRepo.bulkUpdateMarks(
        query: query,
        request: const BulkUpdateExamMarksRequest(
          examId: 'exam_api_1',
          entries: [
            BulkExamMarkEntry(markEntryId: 'exam_api_1_01', marksObtained: 55),
          ],
        ),
      );
      expect(result.savedCount, 1);
      expect(result.updated.first.marksObtained, 55);
      expect(result.failedCount, 1);
      expect(result.failed.first.reason, 'already published');
    });

    test('API progress parses the board rows', () async {
      final remote = ExamRemoteDataSource(
        createFakeDio((options) {
          if (options.path == ExamApiPaths.progress) {
            return {
              'data': [
                {
                  'examId': 'e1',
                  'title': 'T',
                  'subject': 'Maths',
                  'grade': '8',
                  'sectionName': 'A',
                  'enteredCount': 4,
                  'totalCount': 10,
                  'pending': 6,
                },
              ],
            };
          }
          return {'data': []};
        }),
        mapper: mapper,
      );
      final apiRepo = ApiExamAdministrationRepository(remote: remote);
      final rows = await apiRepo.listMarksEntryProgress(query: query);
      expect(rows, hasLength(1));
      expect(rows.first.enteredCount, 4);
      expect(rows.first.totalCount, 10);
      expect(rows.first.pending, 6);
    });

    // ── EXM-6 — marksEntryDeadline round-trips through create ────────────────
    test('mock createExam persists a marksEntryDeadline', () async {
      final repo = MockExamAdministrationRepository();
      final deadline = DateTime.utc(2026, 8, 1, 18, 30);
      final created = await repo.createExam(
        query: query,
        request: CreateExamAdministrationRequest(
          title: 'Deadline Exam',
          subject: 'Mathematics',
          grade: '8',
          section: 'C',
          termLabel: 'Term 2',
          dateLabel: '01 Aug 2026',
          timeLabel: '9:00 AM',
          venueLabel: 'Room 8C',
          syllabusLabel: 'All',
          maxMarks: 50,
          marksEntryDeadline: deadline,
        ),
      );
      expect(created.marksEntryDeadline, deadline);
    });

    test('API createExam sends + parses marksEntryDeadline', () async {
      final remote = ExamRemoteDataSource(
        createFakeDio((options) {
          if (options.path == ExamApiPaths.base &&
              options.method.toUpperCase() == 'POST') {
            final body = options.data as Map<String, dynamic>;
            // Client must have serialized the deadline.
            expect(body['marksEntryDeadline'], isNotNull);
            return {
              'data': {
                'id': 'exam_api_9',
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
                'marksEntryDeadline': body['marksEntryDeadline'],
              },
            };
          }
          return {'data': {}};
        }),
        mapper: mapper,
      );
      final apiRepo = ApiExamAdministrationRepository(remote: remote);
      final created = await apiRepo.createExam(
        query: query,
        request: CreateExamAdministrationRequest(
          title: 'Deadline Exam',
          subject: 'Mathematics',
          grade: '8',
          section: 'C',
          termLabel: 'Term 2',
          dateLabel: '01 Aug 2026',
          timeLabel: '9:00 AM',
          venueLabel: 'Room 8C',
          syllabusLabel: 'All',
          maxMarks: 50,
          marksEntryDeadline: DateTime.utc(2026, 8, 1, 18, 30),
        ),
      );
      expect(created.marksEntryDeadline, DateTime.utc(2026, 8, 1, 18, 30));
    });

    // ── EXM-3/4/5/7 — report reads: mock computes + API parses ───────────────

    test('mock tabulation excludes an AB student from totals/rank', () async {
      final repo = MockExamAdministrationRepository();
      // Mark roll 03 absent, then publish.
      await repo.updateMark(
        query: query,
        request: const UpdateExamMarkRequest(
          markEntryId: 'exam_math_8a_03',
          marksObtained: 0,
          status: ExamMarkStatus.absent,
        ),
      );
      await repo.publishResults(query: query, examId: 'exam_math_8a');

      final reg = await repo.tabulation(
        query: query,
        classLabel: '8-A',
        term: 'Term 2',
      );
      final abStudent = reg.students.firstWhere(
        (s) => s.cellsBySubject['Mathematics']?.statusCode == 'AB',
      );
      expect(abStudent.total, 0);
      expect(abStudent.rank, isNull);
    });

    test('mock merit + toppers + distribution over a published exam', () async {
      final repo = MockExamAdministrationRepository();
      await repo.publishResults(query: query, examId: 'exam_math_8a');

      final merit =
          await repo.meritList(query: query, classLabel: '8-A', term: 'Term 2');
      expect(merit, isNotEmpty);
      expect(merit.first.rank, 1);

      final toppers = await repo.examToppers(
        query: query,
        examId: 'exam_math_8a',
        limit: 3,
      );
      expect(toppers.length, lessThanOrEqualTo(3));
      expect(toppers.first.rank, 1);

      final dist =
          await repo.examDistribution(query: query, examId: 'exam_math_8a');
      expect(dist.presentCount, greaterThan(0));
      expect(dist.passMarkPercent, 40);
    });

    test('mock datesheet lists the class + term schedule', () async {
      final repo = MockExamAdministrationRepository();
      final rows =
          await repo.datesheet(query: query, classLabel: '8-A', term: 'Term 2');
      expect(rows.map((r) => r.subject), contains('Mathematics'));
    });

    test('API report reads parse the server payloads', () async {
      final remote = ExamRemoteDataSource(
        createFakeDio((options) {
          final path = options.path;
          if (path.endsWith('/tabulation')) {
            return {
              'data': {
                'classLabel': '8-A',
                'term': 'Term 2',
                'subjects': ['Mathematics'],
                'students': [
                  {
                    'studentId': 's1',
                    'sisStudentId': 'S1',
                    'studentName': 'Aarav',
                    'rollNo': '01',
                    'perSubject': {
                      'Mathematics': {
                        'marks': 80,
                        'maxMarks': 100,
                        'statusCode': null,
                      },
                    },
                    'total': 80,
                    'totalMax': 100,
                    'percent': 80.0,
                    'rank': 1,
                  },
                  {
                    'studentId': 's2',
                    'sisStudentId': 'S2',
                    'studentName': 'Rohan',
                    'rollNo': '02',
                    'perSubject': {
                      'Mathematics': {
                        'marks': null,
                        'maxMarks': 100,
                        'statusCode': 'AB',
                      },
                    },
                    'total': 0,
                    'totalMax': 0,
                    'percent': 0.0,
                    'rank': null,
                  },
                ],
              },
            };
          }
          if (path.endsWith('/toppers')) {
            return {
              'data': [
                {
                  'sisStudentId': 'S1',
                  'studentName': 'Aarav',
                  'rollNo': '01',
                  'marks': 80,
                  'maxMarks': 100,
                  'percent': 80.0,
                  'rank': 1,
                },
              ],
            };
          }
          if (path.endsWith('/merit')) {
            return {
              'data': [
                {
                  'sisStudentId': 'S1',
                  'studentName': 'Aarav',
                  'rollNo': '01',
                  'total': 80,
                  'totalMax': 100,
                  'percent': 80.0,
                  'rank': 1,
                },
              ],
            };
          }
          if (path.endsWith('/distribution')) {
            return {
              'data': {
                'examId': 'exam-1',
                'passMarkPercent': 40,
                'passMarkSource': 'default',
                'passCount': 1,
                'failCount': 0,
                'gradeBreakdown': [
                  {'grade': 'A', 'count': 1},
                ],
                'presentCount': 1,
                'excludedCount': 1,
              },
            };
          }
          if (path.endsWith('/datesheet')) {
            return {
              'data': [
                {
                  'examId': 'exam-1',
                  'subject': 'Mathematics',
                  'dateLabel': '12 Jun 2026',
                  'timeLabel': '9:00 AM',
                  'venueLabel': 'Room 8A',
                  'maxMarks': 100,
                },
              ],
            };
          }
          return {'data': {}};
        }),
        mapper: mapper,
      );
      final apiRepo = ApiExamAdministrationRepository(remote: remote);

      final reg = await apiRepo.tabulation(
        query: query,
        classLabel: '8-A',
        term: 'Term 2',
      );
      expect(reg.subjects, ['Mathematics']);
      // The AB row parses with a null mark + 'AB' code and null rank.
      final ab = reg.students.firstWhere((s) => s.sisStudentId == 'S2');
      expect(ab.cellsBySubject['Mathematics']!.statusCode, 'AB');
      expect(ab.cellsBySubject['Mathematics']!.marks, isNull);
      expect(ab.rank, isNull);

      final toppers =
          await apiRepo.examToppers(query: query, examId: 'exam-1', limit: 5);
      expect(toppers.single.marks, 80);

      final merit = await apiRepo.meritList(
        query: query,
        classLabel: '8-A',
        term: 'Term 2',
      );
      expect(merit.single.rank, 1);

      final dist =
          await apiRepo.examDistribution(query: query, examId: 'exam-1');
      expect(dist.passCount, 1);
      expect(dist.excludedCount, 1);
      expect(dist.gradeBreakdown.single.grade, 'A');

      final datesheet = await apiRepo.datesheet(
        query: query,
        classLabel: '8-A',
        term: 'Term 2',
      );
      expect(datesheet.single.subject, 'Mathematics');
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
