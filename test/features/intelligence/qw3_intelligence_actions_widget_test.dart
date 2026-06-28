import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/features/intelligence/intelligence_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-060 — Akshara Intelligence generate-report + publish-to-parent
/// actions. `intelligence_screen.dart` was 0% lcov / never pumped. Covers the
/// AI action surface: compute-risk generate, and the Parent Guidance
/// generate→publish flow (publish ON → "published" parent-hub confirmation,
/// publish OFF → "draft"). Actions are RBAC-gated via `generateIntelligence`,
/// exercised through the QA super-admin role matrix.
Future<void> _pump(WidgetTester tester) async {
  // Tall surface so the multi-field intelligence tabs lay out without the
  // generate buttons being pushed off-screen.
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        // QA-login env → superAdmin maps to the full permission matrix, so the
        // RBAC-gated generate/publish actions render and run.
        environmentProvider.overrideWith(
          (ref) => Environment.development.copyWith(enableQaLogin: true),
        ),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const IntelligenceScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-060 · IntelligenceScreen', () {
    testWidgets('renders the five intelligence tabs', (tester) async {
      await _pump(tester);

      expect(find.text('Akshara Intelligence'), findsOneWidget);
      expect(find.text('Student Risk'), findsOneWidget);
      expect(find.text('Parent Guidance'), findsOneWidget);
      expect(find.text('Principal Center'), findsOneWidget);
    });

    testWidgets('Compute student risks generates and confirms via snackbar',
        (tester) async {
      await _pump(tester);

      // Student Risk tab is active by default.
      await tester.tap(find.widgetWithText(FilledButton, 'Compute student risks'));
      await settleRiverpodFutures(tester);
      await tester.pump(); // surface the snackbar

      expect(find.textContaining('Computed risk for'), findsOneWidget);
    });

    testWidgets('Generate & publish guidance publishes to the parent hub',
        (tester) async {
      await _pump(tester);

      // Switch to the Parent Guidance tab.
      await tester.tap(find.text('Parent Guidance'));
      await tester.pumpAndSettle();

      // Publish-to-parent-hub switch defaults ON.
      expect(find.text('Publish to parent hub'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Generate & publish guidance'),
      );
      await settleRiverpodFutures(tester);
      await tester.pump(); // surface the snackbar

      // Publish call fired with publish=true → parent-hub confirmation.
      expect(
        find.text('Guidance published — visible in parent hub'),
        findsOneWidget,
      );
      // The generated guidance report card renders its progress summary.
      expect(find.text('Progress summary'), findsOneWidget);
    });

    testWidgets('Publish toggle off saves the guidance as a draft instead',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Parent Guidance'));
      await tester.pumpAndSettle();

      // Turn the publish switch OFF.
      await tester.tap(find.text('Publish to parent hub'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Generate & publish guidance'),
      );
      await settleRiverpodFutures(tester);
      await tester.pump();

      // Publish call fired with publish=false → draft, not parent-hub publish.
      expect(find.text('Guidance saved as draft'), findsOneWidget);
      expect(
        find.text('Guidance published — visible in parent hub'),
        findsNothing,
      );
    });
  });
}
