import 'package:akshara_erp/core/timetable/class_teacher_assignments.dart';
import 'package:akshara_erp/features/school_completion/class_teacher_assignment_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ClassTeacherAssignmentStore.instance.reset());
  tearDown(() => ClassTeacherAssignmentStore.instance.reset());

  Widget buildTestApp() {
    return MaterialApp(
      theme: AksharaAppTheme.light(),
      home: const ClassTeacherAssignmentScreen(),
    );
  }

  group('ClassTeacherAssignmentScreen', () {
    testWidgets('lists sections with their current class teacher', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Class teachers'), findsOneWidget);
      expect(find.text('Class 8-A'), findsOneWidget);
      expect(find.text('Class 8-B'), findsOneWidget);
      // Seeded class teacher names are shown.
      expect(find.textContaining('Priya Sharma'), findsWidgets);
    });

    testWidgets('changing the dropdown reassigns the class teacher', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Open the first section's dropdown and pick Mrs. Rao.
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mrs. Rao').last);
      await tester.pumpAndSettle();

      expect(ClassTeacherAssignmentStore.instance.teacherFor('8-A'), 'HR-EMP-102');
    });
  });
}
