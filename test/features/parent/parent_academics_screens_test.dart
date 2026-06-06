import 'package:akshara_erp/features/parent/exams/parent_exams_provider.dart';
import 'package:akshara_erp/features/parent/exams/parent_exams_screen.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_provider.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_screen.dart';
import 'package:akshara_erp/features/parent/timetable/parent_timetable_provider.dart';
import 'package:akshara_erp/features/parent/timetable/parent_timetable_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> pumpParentScreen(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Parent academics screens', () {
    testWidgets('ParentTimetableScreen renders timetable content', (
      tester,
    ) async {
      await pumpParentScreen(tester, const ParentTimetableScreen());

      expect(find.text('Timetable'), findsOneWidget);
      expect(find.textContaining('Ravi Kumar'), findsWidgets);
      expect(find.text('Mathematics'), findsWidgets);
    });

    testWidgets('ParentTimetableScreen shows loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentTimetableLoadingProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentTimetableScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('ParentHomeworkScreen renders homework list', (tester) async {
      await pumpParentScreen(tester, const ParentHomeworkScreen());

      expect(find.text('Homework'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('ParentHomeworkScreen shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentHomeworkErrorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentHomeworkScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(
        find.text('Unable to load homework right now.'),
        findsOneWidget,
      );
    });

    testWidgets('ParentExamsScreen renders upcoming exams', (tester) async {
      await pumpParentScreen(tester, const ParentExamsScreen());

      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Results'), findsOneWidget);
    });

    testWidgets('ParentExamsScreen shows empty state when forced empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentExamsEmptyProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentExamsScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });
  });
}
