import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/widgets/attendance_exception_grid.dart';
import 'package:akshara_erp/shared/marks_grid/marks_grid.dart';
import 'package:akshara_erp/theme/accessibility.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-UX-4 (Polish §7): dynamic-type support, with the ONE permitted clamp on
// dense fixed-size grids capped at 1.3×. These tests pin the clamp helper, prove
// the two dense grids actually apply it, and prove they don't overflow at 2.0×.

Widget _scaled({required Widget home, double scale = 1.0, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AksharaAppTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: home,
      ),
    ),
  );
}

void main() {
  group('P2-UX-4 · clampDenseGridTextScale', () {
    test('caps above 1.3× and is a no-op within the cap', () {
      expect(
        AksharaAccessibility.clampDenseGridTextScale(const TextScaler.linear(2.0))
            .scale(10),
        13.0,
      );
      expect(
        AksharaAccessibility.clampDenseGridTextScale(const TextScaler.linear(1.6))
            .scale(10),
        13.0,
      );
      expect(
        AksharaAccessibility.clampDenseGridTextScale(const TextScaler.linear(1.3))
            .scale(10),
        13.0,
      );
      expect(
        AksharaAccessibility.clampDenseGridTextScale(const TextScaler.linear(1.2))
            .scale(10),
        12.0,
      );
      expect(
        AksharaAccessibility.clampDenseGridTextScale(TextScaler.noScaling).scale(10),
        10.0,
      );
    });
  });

  group('P2-UX-4 · dense grids clamp + do not overflow at 2.0×', () {
    testWidgets('AttendanceExceptionGrid', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final students = List.generate(
        8,
        (i) => TeacherAttendanceStudent(
          id: 's$i',
          name: 'Student Number $i',
          rollNo: '${i + 1}',
          mark: i.isEven
              ? StudentAttendanceMark.absent
              : StudentAttendanceMark.present,
        ),
      );

      await tester.pumpWidget(_scaled(
        scale: 2.0,
        home: Scaffold(
          body: AttendanceExceptionGrid(
            students: students,
            enabled: true,
            onMark: (_, __) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final gridContext = tester.element(find.byType(GridView));
      expect(
        MediaQuery.textScalerOf(gridContext).scale(1),
        lessThanOrEqualTo(AksharaAccessibility.maxDenseGridTextScale + 1e-9),
      );
    });

    testWidgets('MarksEntryField', (tester) async {
      await tester.pumpWidget(_scaled(
        scale: 2.0,
        home: Scaffold(
          body: Center(
            child: MarksEntryField(
              controller: TextEditingController(text: '88'),
              maxMarks: 100,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final fieldContext = tester.element(find.byType(TextField));
      expect(
        MediaQuery.textScalerOf(fieldContext).scale(1),
        lessThanOrEqualTo(AksharaAccessibility.maxDenseGridTextScale + 1e-9),
      );
    });
  });

  group('P2-UX-4 · onColorFor (badge legibility)', () {
    test('picks the higher-contrast of black / white', () {
      // A bright fill (a dark-scheme semantic tone) → a black glyph.
      expect(AksharaAccessibility.onColorFor(const Color(0xFF4ADE80)), Colors.black);
      // A dark fill (a light-scheme semantic tone) → a white glyph.
      expect(AksharaAccessibility.onColorFor(const Color(0xFF15803D)), Colors.white);
    });

    test('always clears the WCAG large-text floor on the fill', () {
      for (final fill in const [
        Color(0xFF4ADE80), // success (dark scheme)
        Color(0xFFFBBF24), // warning (dark scheme)
        Color(0xFF15803D), // success (light scheme)
        Color(0xFFD97706), // warning (light scheme)
        Color(0xFF4F46E5), // indigo/primary
        Color(0xFF0D9488), // tertiary/teal
        Color(0xFF64748B), // neutral
        Color(0xFF818CF8), // indigo (dark scheme)
      ]) {
        expect(
          AksharaAccessibility.contrastRatio(
            AksharaAccessibility.onColorFor(fill),
            fill,
          ),
          greaterThanOrEqualTo(AksharaAccessibility.minContrastLargeText),
          reason: '$fill',
        );
      }
    });
  });
}
