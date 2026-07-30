import 'package:akshara_erp/features/academics/timetable/substitutions/daily_substitutions_provider.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:akshara_erp/features/teacher/timetable/teacher_today_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// TCH-4 · honest state — the "Today's cover" banner used to drop BOTH loading
/// and error to `SizedBox.shrink()`. A teacher assigned a substitution whose
/// cover read failed therefore saw nothing at all and could miss the class.
/// A failed read must now be visible (and must never show the raw exception).

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherTodayScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Override _failingCoverOverride() =>
    dailySubstitutionsProvider.overrideWith((ref) async {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/functions/v1/timetable-substitutions',
          baseUrl: 'https://internal-db.akshara.invalid',
        ),
        type: DioExceptionType.connectionError,
        message: 'SocketException: Failed host lookup',
      );
    });

void main() {
  group("TCH-4 · today's cover banner", () {
    testWidgets('a failed cover read is surfaced, not silently dropped',
        (tester) async {
      await _pump(tester, overrides: [_failingCoverOverride()]);

      expect(
        find.byKey(const Key('teacher_today_cover_error')),
        findsOneWidget,
      );
      expect(
        find.textContaining("Couldn't check today's cover"),
        findsOneWidget,
      );
      // It is not passed off as "nothing scheduled today".
      expect(
        find.text('No classes scheduled for you today.'),
        findsNothing,
      );

      for (final leak in const [
        'DioException',
        'internal-db.akshara.invalid',
        'timetable-substitutions',
        'SocketException',
      ]) {
        expect(
          find.textContaining(leak),
          findsNothing,
          reason: 'raw exception detail "$leak" reached the UI',
        );
      }
    });

    testWidgets('a resolved read with no cover still renders no banner',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          dailySubstitutionsProvider
              .overrideWith((ref) async => DailySubstitutionsBundle.empty),
        ],
      );

      expect(
        find.byKey(const Key('teacher_today_cover_error')),
        findsNothing,
      );
      expect(find.textContaining("Couldn't check today's cover"), findsNothing);
    });
  });
}
