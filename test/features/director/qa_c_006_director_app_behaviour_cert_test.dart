import 'dart:async';

import 'package:akshara_erp/features/director/director_compliance_screen.dart';
import 'package:akshara_erp/features/director/director_models.dart';
import 'package:akshara_erp/features/director/director_providers.dart';
import 'package:akshara_erp/features/director/director_reports_screen.dart';
import 'package:akshara_erp/features/director/director_revenue_screen.dart';
import 'package:akshara_erp/features/director/director_schools_screen.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW7 · QA-C-006 — Director / Control-Center *behaviour* certification (Batch 2).
///
/// Sits ON TOP of the existing Director coverage which already proves rendering,
/// the 4 async states, entitlement gating, and the error-path actions:
///   • test/features/director/qw3_director_subscreens_widget_test.dart  (QA-F-054:
///     every sub-screen renders demo data + privacy banner; revenue loading;
///     compliance error; schools empty)
///   • test/features/director/director_action_error_handling_test.dart  (DIREC-1
///     plan-locked gate; DIREC-2 summary-failure snackbar; DIREC-3 acknowledge-
///     failure snackbar)
///   • test/features/director/director_dashboard_screen_test.dart
///   • test/features/director/qw5_director_board_pack_entitlement_test.dart
///
/// This cert adds the HAPPY-PATH clickable behaviour the error suite is the mirror
/// of: tapping "Generate AI Executive Summary" runs the action and REPLACES the
/// placeholder brief with a generated one (no error snackbar) — plus a direct
/// re-assert of the canonical loading / error / empty / success states.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  // Phone-sized window keeps director cards fully laid out (the data-table path
  // virtualizes rows on wide windows).
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  const summaryPlaceholder =
      'Generate a board-ready executive brief from aggregated portfolio metrics.';

  group('QA-C-006 · Director — clickable behaviour (happy path)', () {
    testWidgets(
        'Generate AI Executive Summary replaces the placeholder with no error',
        (tester) async {
      await _pump(tester, const DirectorReportsScreen());

      // Before: the brief card shows its call-to-action placeholder.
      expect(find.text(summaryPlaceholder), findsOneWidget);

      // Tap the generate CTA → the demo repository returns a brief.
      await tester.tap(find.text('Generate AI Executive Summary'));
      await tester.pumpAndSettle();

      // After: the placeholder is gone (replaced by the generated brief) and NO
      // failure snackbar surfaced.
      expect(find.text(summaryPlaceholder), findsNothing);
      expect(
        find.textContaining('Could not generate executive summary'),
        findsNothing,
      );
    });
  });

  group('QA-C-006 · Director — canonical 4 states render', () {
    testWidgets('SUCCESS — schools renders demo data, no placeholders',
        (tester) async {
      await _pump(tester, const DirectorSchoolsScreen());

      expect(find.text(kDirectorPrivacyBannerMessage), findsOneWidget);
      expect(find.byType(AksharaLoadingState), findsNothing);
      expect(find.byType(AksharaErrorState), findsNothing);
    });

    testWidgets('LOADING — revenue shows AksharaLoadingState while pending',
        (tester) async {
      final pending = Completer<DirectorRevenueSnapshot>();
      addTearDown(() {
        if (!pending.isCompleted) {
          pending.complete(
            const DirectorRevenueSnapshot(
              chainRevenueCr: 0,
              expensesCr: 0,
              netCr: 0,
              marginPercent: 0,
              forecastCr: 0,
              revenueBySchool: [],
              revenueTrend: [],
            ),
          );
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            directorRevenueProvider.overrideWith((ref) => pending.future),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const DirectorRevenueScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('EMPTY — schools shows the empty portfolio message',
        (tester) async {
      await _pump(
        tester,
        const DirectorSchoolsScreen(),
        overrides: [
          directorSchoolsProvider
              .overrideWith((ref) async => const <DirectorSchoolRow>[]),
        ],
      );

      expect(
        find.text('No schools available in this portfolio.'),
        findsOneWidget,
      );
    });

    testWidgets('ERROR — compliance shows AksharaErrorState on failure',
        (tester) async {
      await _pump(
        tester,
        const DirectorComplianceScreen(),
        overrides: [
          directorComplianceProvider.overrideWith(
            (ref) => Future<List<DirectorComplianceItem>>.error(
              Exception('compliance boom'),
            ),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
