import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/core/timetable/mock_daily_timetable_store.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_timetable_screen.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_today_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

void main() {
  setUp(MockDailyTimetableStore.instance.reset);

  group('TCH-1 · today-period rows navigate to attendance', () {
    testWidgets('tapping a period opens attendance with the class in the URL',
        (tester) async {
      useMobileViewport(tester);
      String? landedUri;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const TeacherTodayScreen(),
          ),
          GoRoute(
            path: RouteNames.teacherAttendance,
            builder: (_, state) {
              landedUri = state.uri.toString();
              return const SizedBox();
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The default demo teacher (class teacher of 8-A) has periods today.
      final row = find.byType(InkWell).first;
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(landedUri, isNotNull);
      expect(landedUri, startsWith(RouteNames.teacherAttendance));
      expect(landedUri, contains('class='));
    });
  });

  group('TCH-3 · attendance register export', () {
    testWidgets('renders an export action on the attendance screen',
        (tester) async {
      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const TeacherAttendanceScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.teacherAttendanceExportButton),
        findsOneWidget,
      );
    });
  });

  group('TCH-4 · timetable cover surface', () {
    testWidgets('the weekly timetable shows the cover line', (tester) async {
      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const TeacherTimetableScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Mock Friday P5 is a cover for Mrs. Rao (default day = fri).
      expect(find.textContaining('Covering Mrs. Rao'), findsOneWidget);
      expect(find.text('Cover'), findsWidgets);
    });
  });
}
