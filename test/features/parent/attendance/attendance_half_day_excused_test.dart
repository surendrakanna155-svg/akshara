import 'package:akshara_erp/core/repositories/api/parent/dto/parent_enum_codec.dart';
import 'package:akshara_erp/core/repositories/api/student/dto/student_enum_codec.dart';
import 'package:akshara_erp/features/parent/attendance/attendance_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ATT-D3 — parent/student calendar renders half-day + excused as distinct
// statuses, and the wire codecs decode the backend's camelCase status strings.
void main() {
  group('AttendanceDayStatus half-day + excused', () {
    test('enum carries halfDay and excused', () {
      expect(AttendanceDayStatus.values.contains(AttendanceDayStatus.halfDay),
          isTrue);
      expect(AttendanceDayStatus.values.contains(AttendanceDayStatus.excused),
          isTrue);
    });

    test('parent codec decodes halfDay / excused from the wire', () {
      expect(
        ParentEnumCodec.parseAttendanceDayStatus('halfDay'),
        AttendanceDayStatus.halfDay,
      );
      expect(
        ParentEnumCodec.parseAttendanceDayStatus('excused'),
        AttendanceDayStatus.excused,
      );
    });

    test('student codec decodes halfDay / excused from the wire', () {
      expect(
        StudentEnumCodec.parseAttendanceDayStatus('halfDay'),
        AttendanceDayStatus.halfDay,
      );
      expect(
        StudentEnumCodec.parseAttendanceDayStatus('excused'),
        AttendanceDayStatus.excused,
      );
    });

    testWidgets('resolve() gives half-day + excused distinct labels/colours',
        (tester) async {
      late ({String label, Color background, Color foreground}) halfDay;
      late ({String label, Color background, Color foreground}) excused;
      late ({String label, Color background, Color foreground}) present;

      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Builder(
            builder: (context) {
              halfDay = AttendanceDayStatus.halfDay.resolve(context);
              excused = AttendanceDayStatus.excused.resolve(context);
              present = AttendanceDayStatus.present.resolve(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(halfDay.label, 'Half-day');
      expect(excused.label, 'Excused');
      // Distinct from present and from each other.
      expect(halfDay.background, isNot(present.background));
      expect(excused.background, isNot(present.background));
      expect(halfDay.background, isNot(excused.background));
    });
  });
}
