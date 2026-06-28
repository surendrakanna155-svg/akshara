import 'dart:async';

import 'package:akshara_erp/features/director/director_admissions_screen.dart';
import 'package:akshara_erp/features/director/director_compliance_screen.dart';
import 'package:akshara_erp/features/director/director_growth_screen.dart';
import 'package:akshara_erp/features/director/director_marketing_screen.dart';
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

/// QW3 · QA-F-054 — Director multi-school sub-screens (B8). Each director sub-
/// screen shares the AsyncValue.when(loading/error/data) + DirectorModuleScaffold
/// pattern reading a `directorXxxProvider` (FutureProvider backed by the demo
/// MockDirectorRepository). This is table-driven: every sub-screen is pumped
/// against demo data and asserted to render its distinctive content + the shared
/// privacy banner, then loading + error states are forced on one screen each.

Future<void> _pump(WidgetTester tester, Widget screen,
    {List<Override> overrides = const []}) async {
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

/// (label, screen) for the render sweep. Each screen is asserted to settle into
/// its data path (shared privacy banner present, no loading/error placeholder).
const _renderCases = <(String, Widget)>[
  ('schools', DirectorSchoolsScreen()),
  ('revenue', DirectorRevenueScreen()),
  ('growth', DirectorGrowthScreen()),
  ('marketing', DirectorMarketingScreen()),
  ('admissions', DirectorAdmissionsScreen()),
  ('compliance', DirectorComplianceScreen()),
  ('reports', DirectorReportsScreen()),
];

void main() {
  group('QA-F-054 · Director sub-screens', () {
    for (final (label, screen) in _renderCases) {
      testWidgets('$label renders demo data + the privacy banner',
          (tester) async {
        await _pump(tester, screen);

        // The shared scaffold always shows the director privacy banner.
        expect(find.text(kDirectorPrivacyBannerMessage), findsOneWidget);
        // The data path resolved — no loading/error placeholders linger.
        expect(find.byType(AksharaLoadingState), findsNothing);
        expect(find.byType(AksharaErrorState), findsNothing);
        expect(find.byWidget(screen), findsOneWidget);
      });
    }

    testWidgets('revenue shows the loading state while its provider is pending',
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

    testWidgets('compliance shows the error state when its provider fails',
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

    testWidgets('schools shows the empty state when the portfolio is empty',
        (tester) async {
      await _pump(
        tester,
        const DirectorSchoolsScreen(),
        overrides: [
          directorSchoolsProvider.overrideWith(
            (ref) async => const <DirectorSchoolRow>[],
          ),
        ],
      );

      expect(
        find.text('No schools available in this portfolio.'),
        findsOneWidget,
      );
    });
  });
}
