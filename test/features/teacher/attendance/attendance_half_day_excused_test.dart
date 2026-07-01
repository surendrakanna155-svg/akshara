import 'package:akshara_erp/core/repositories/api/teacher/dto/teacher_enum_codec.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

// ATT-D3 — the half-day + excused marks on the teacher enum, its wire codec,
// and the summary counts on TeacherAttendanceData.
void main() {
  group('StudentAttendanceMark half-day + excused', () {
    test('enum carries halfDay and excused with sensible labels', () {
      expect(StudentAttendanceMark.halfDay.label, 'Half-day');
      expect(StudentAttendanceMark.excused.label, 'Excused');
      expect(StudentAttendanceMark.halfDay.shortLabel, 'H');
      expect(StudentAttendanceMark.excused.shortLabel, 'E');
    });

    test('wire codec maps halfDay <-> half_day (snake) so the DB CHECK holds', () {
      expect(
        TeacherEnumCodec.studentAttendanceMarkToApi(
          StudentAttendanceMark.halfDay,
        ),
        'half_day',
      );
      expect(
        TeacherEnumCodec.parseStudentAttendanceMark('half_day'),
        StudentAttendanceMark.halfDay,
      );
    });

    test('wire codec round-trips excused verbatim', () {
      expect(
        TeacherEnumCodec.studentAttendanceMarkToApi(
          StudentAttendanceMark.excused,
        ),
        'excused',
      );
      expect(
        TeacherEnumCodec.parseStudentAttendanceMark('excused'),
        StudentAttendanceMark.excused,
      );
    });

    test('existing marks are unchanged by the wire codec', () {
      for (final mark in [
        StudentAttendanceMark.present,
        StudentAttendanceMark.absent,
        StudentAttendanceMark.late,
      ]) {
        final wire = TeacherEnumCodec.studentAttendanceMarkToApi(mark);
        expect(wire, mark.name);
        expect(TeacherEnumCodec.parseStudentAttendanceMark(wire), mark);
      }
    });

    test('TeacherAttendanceData counts half-day and excused students', () {
      const data = TeacherAttendanceData(
        classes: [],
        students: [
          TeacherAttendanceStudent(
            id: 'a',
            name: 'A',
            rollNo: '1',
            mark: StudentAttendanceMark.present,
          ),
          TeacherAttendanceStudent(
            id: 'b',
            name: 'B',
            rollNo: '2',
            mark: StudentAttendanceMark.halfDay,
          ),
          TeacherAttendanceStudent(
            id: 'c',
            name: 'C',
            rollNo: '3',
            mark: StudentAttendanceMark.excused,
          ),
          TeacherAttendanceStudent(
            id: 'd',
            name: 'D',
            rollNo: '4',
            mark: StudentAttendanceMark.excused,
          ),
        ],
        selectedClassId: 'x',
        unreadNotifications: 0,
      );

      expect(data.presentCount, 1);
      expect(data.halfDayCount, 1);
      expect(data.excusedCount, 2);
      expect(data.unmarkedCount, 0);
    });
  });
}
