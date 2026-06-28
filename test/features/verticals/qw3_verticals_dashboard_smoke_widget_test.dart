import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/verticals/restaurant/restaurant_dashboard_screen.dart';
import 'package:akshara_erp/features/verticals/salon/salon_dashboard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-061 — Verticals drill-down screens.
///
/// SCOPE NOTE (owner decision 2026-06-18, see lib/core/config/school_build_scope.dart):
/// the non-school business verticals (restaurant / salon / healthcare /
/// accommodation) are HIDDEN ("hide now, delete later") in the shipping school
/// build — `SchoolBuildScope.enabled == true` lists them in both
/// `hiddenAdminModules` and `hiddenRoutePrefixes`, and the route guards
/// (lib/router/route_guards.dart, app_router.dart) block their routes. They are
/// therefore UNREACHABLE via navigation, so a full drill-down JOURNEY test would
/// contradict the scope decision.
///
/// Per the QW3 scope-flag instruction we instead assert the screens still BUILD
/// in isolation (they are hidden, not deleted, and can be restored by flipping
/// the scope switch). This documents the modules remain render-safe with demo
/// data and guards regression of the hidden-but-present code.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      // QA-login env → superAdmin maps to the full permission matrix, so the
      // vertical view permission (viewSalonBusiness / viewRestaurantHospitality)
      // is granted and the dashboards render their demo content.
      overrides: erpWidgetTestOverrides([
        environmentProvider.overrideWith(
          (ref) => Environment.development.copyWith(enableQaLogin: true),
        ),
      ]),
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
  group('QA-F-061 · Verticals dashboards (scoped-out, isolation smoke)', () {
    testWidgets('Salon dashboard builds with demo data', (tester) async {
      await _pump(tester, const SalonDashboardScreen());

      expect(find.byKey(QaTestKeys.salonDashboardScreen), findsOneWidget);
      expect(find.text('Salon'), findsOneWidget);
      // Demo summary + at least the drill-down nav links render.
      expect(find.byKey(QaTestKeys.salonDashboardSummary), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
    });

    testWidgets('Restaurant dashboard builds with demo data', (tester) async {
      await _pump(tester, const RestaurantDashboardScreen());

      expect(find.byKey(QaTestKeys.restaurantDashboardScreen), findsOneWidget);
      expect(find.text('Restaurant'), findsOneWidget);
      expect(find.byKey(QaTestKeys.restaurantDashboardSummary), findsOneWidget);
      expect(find.text('Tables'), findsOneWidget);
    });
  });
}
