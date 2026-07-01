import 'package:akshara_erp/core/repositories/api/attendance/api_attendance_office_repository.dart';
import 'package:akshara_erp/core/repositories/api/attendance/remote/attendance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/attendance/remote/attendance_office_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_office_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Office attendance repository contract (mock)', () {
    const repo = MockAttendanceOfficeRepository();

    test('ATT-1 register returns per-student rows for a class + date', () async {
      final rows = await repo.fetchRegister(
        query: query,
        classLabel: '8-A',
        date: DateTime(2026, 7, 1),
      );
      expect(rows, isNotEmpty);
      expect(rows.first.classLabel, '8-A');
      // Marks are capitalized human-readable strings.
      expect(rows.map((r) => r.mark),
          everyElement(anyOf('Present', 'Absent', 'Late', 'Excused')));
    });

    test('ATT-2 monthly returns a students×days matrix with % present', () async {
      final register = await repo.fetchMonthlyRegister(
        query: query,
        classLabel: '8-A',
        month: '2026-07',
      );
      expect(register.classLabel, '8-A');
      expect(register.month, '2026-07');
      expect(register.dayCount, 31);
      expect(register.students, isNotEmpty);
      final s = register.students.first;
      expect(s.percentPresent, inInclusiveRange(0, 100));
      expect(s.markedDays, greaterThan(0));
    });

    test('ATT-4 pending returns classes without a submitted session', () async {
      final rows = await repo.fetchPending(query: query, date: DateTime(2026, 7, 1));
      expect(rows, isNotEmpty);
      expect(rows.map((r) => r.status), contains('draft'));
    });

    test('ATT-D1 consecutive-absence returns flagged students', () async {
      final rows = await repo.fetchConsecutiveAbsences(query: query, days: 3);
      expect(rows, isNotEmpty);
      expect(rows.first.consecutiveDays, 3);
    });

    test('ATT-D2 short-attendance filters by threshold', () async {
      final at75 = await repo.fetchShortAttendance(query: query, threshold: 75);
      final at60 = await repo.fetchShortAttendance(query: query, threshold: 60);
      expect(at75.length, greaterThanOrEqualTo(at60.length));
      expect(at75, everyElement(predicate((r) =>
          (r as dynamic).percentPresent < 75)));
    });
  });

  group('Office attendance API fake-Dio parity', () {
    final remote = AttendanceOfficeRemoteDataSource(
      createFakeDio((options) {
        if (options.path == AttendanceApiPaths.register) {
          return {
            'data': [
              {
                'studentId': 'stu_1',
                'name': 'Arjun Patel',
                'roll': '1',
                'classLabel': '8-A',
                'mark': 'Present',
              },
              {
                'studentId': 'stu_2',
                'name': 'Bhavya Reddy',
                'roll': '2',
                'classLabel': '8-A',
                'mark': 'Absent',
              },
            ],
          };
        }
        if (options.path == AttendanceApiPaths.monthlyRegister) {
          return {
            'data': {
              'classLabel': '8-A',
              'month': '2026-07',
              'dayCount': 31,
              'students': [
                {
                  'studentId': 'stu_1',
                  'name': 'Arjun Patel',
                  'roll': '1',
                  'classLabel': '8-A',
                  'marks': {'1': 'P', '2': 'A', '3': 'L'},
                  'presentDays': 2,
                  'markedDays': 3,
                  'percentPresent': 67,
                },
              ],
            },
          };
        }
        if (options.path == AttendanceApiPaths.pending) {
          return {
            'data': [
              {
                'classLabel': '9-A',
                'status': 'draft',
                'takenBy': 't1',
                'teacherName': 'Ms. Rao',
                'lastSavedAt': '2026-07-01T08:00:00Z',
              },
            ],
          };
        }
        if (options.path == AttendanceApiPaths.consecutiveAbsenceAlert) {
          return {
            'data': [
              {
                'studentId': 'stu_3',
                'name': 'Chetan Kumar',
                'roll': '3',
                'classLabel': '8-A',
                'consecutiveDays': 3,
                'lastAbsentDate': '2026-07-01',
              },
            ],
          };
        }
        if (options.path == AttendanceApiPaths.shortAttendanceAlert) {
          return {
            'data': [
              {
                'studentId': 'stu_3',
                'name': 'Chetan Kumar',
                'roll': '3',
                'classLabel': '8-A',
                'presentDays': 11,
                'markedDays': 22,
                'percentPresent': 50,
              },
            ],
          };
        }
        return {'data': {}};
      }),
    );
    final apiRepo = ApiAttendanceOfficeRepository(remote: remote);

    test('register maps rows', () async {
      final rows = await apiRepo.fetchRegister(
        query: query,
        classLabel: '8-A',
        date: DateTime(2026, 7, 1),
      );
      expect(rows, hasLength(2));
      expect(rows.first.name, 'Arjun Patel');
      expect(rows.last.mark, 'Absent');
    });

    test('monthly maps matrix + %', () async {
      final register = await apiRepo.fetchMonthlyRegister(
        query: query,
        classLabel: '8-A',
        month: '2026-07',
      );
      expect(register.students, hasLength(1));
      expect(register.students.first.codeForDay(2), 'A');
      expect(register.students.first.codeForDay(99), '–'); // unmarked
      expect(register.students.first.percentPresent, 67);
    });

    test('pending maps status + teacher + last saved', () async {
      final rows = await apiRepo.fetchPending(query: query, date: DateTime(2026, 7, 1));
      expect(rows, hasLength(1));
      expect(rows.first.isDraft, isTrue);
      expect(rows.first.teacherName, 'Ms. Rao');
      expect(rows.first.lastSavedAt, isNotNull);
    });

    test('consecutive-absence maps rows', () async {
      final rows = await apiRepo.fetchConsecutiveAbsences(query: query, days: 3);
      expect(rows, hasLength(1));
      expect(rows.first.consecutiveDays, 3);
      expect(rows.first.lastAbsentDate, isNotNull);
    });

    test('short-attendance maps rows', () async {
      final rows = await apiRepo.fetchShortAttendance(query: query, threshold: 75);
      expect(rows, hasLength(1));
      expect(rows.first.percentPresent, 50);
      expect(rows.first.markedDays, 22);
    });
  });
}
