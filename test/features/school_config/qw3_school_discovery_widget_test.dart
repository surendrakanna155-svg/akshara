import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/school_config/school_discovery_screen.dart';
import 'package:akshara_erp/shared/forms/forms.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-052 — Guided School Configuration discovery wizard (FV-PLAT-14).
/// `school_discovery_screen.dart` drives the school-type/curriculum/capability
/// selection + the apply-configuration save. Covers: list/form render, option
/// selection across the multi-step wizard, capability toggle, and a full
/// walk-through to "Apply configuration" that asserts the config is persisted to
/// the configuration provider and the applied snackbar renders.

// Bare host for render/selection checks (the wizard never pops mid-flow).
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
        home: const SchoolDiscoveryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-052 · SchoolDiscoveryScreen', () {
    testWidgets('renders the multi-step form and school-type choices',
        (tester) async {
      await _pump(tester);

      expect(find.text('Guided School Configuration'), findsOneWidget);
      expect(find.byType(AksharaMultiStepForm), findsOneWidget);
      // Step 0 lists every selectable school type as a tappable option.
      for (final type in SchoolType.values) {
        expect(
          find.byKey(QaTestKeys.schoolDiscoverySchoolTypeOption(type.storageKey)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(QaTestKeys.schoolDiscoveryContinueButton),
        findsOneWidget,
      );
    });

    testWidgets('selecting a school type marks it checked', (tester) async {
      await _pump(tester);

      // Preschool is not the default (day school) — selecting it should toggle
      // the check marker onto that option.
      await tester.tap(
        find.byKey(
          QaTestKeys.schoolDiscoverySchoolTypeOption(
            SchoolType.preschool.storageKey,
          ),
        ),
      );
      await tester.pump();

      final selectedTile = tester.widget<ListTile>(
        find.byKey(
          QaTestKeys.schoolDiscoverySchoolTypeOption(
            SchoolType.preschool.storageKey,
          ),
        ),
      );
      expect(selectedTile.trailing, isA<Icon>());
      expect((selectedTile.trailing! as Icon).icon, Icons.check_circle);
    });

    testWidgets('walking the wizard and applying persists the configuration',
        (tester) async {
      // A container we can read after apply to prove the durable save happened.
      final container = ProviderContainer(
        overrides: erpWidgetTestOverrides(),
      );
      addTearDown(container.dispose);

      // Host the wizard in a GoRouter and push it onto the home route so its
      // post-apply `context.pop()` has a route to return to (mirrors how the
      // launching surface opens the wizard).
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/discovery',
            builder: (_, __) => const SchoolDiscoveryScreen(),
          ),
        ],
      );

      useMobileViewport(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/discovery');
      await tester.pumpAndSettle();

      // Step 0 — pick High School.
      await tester.tap(
        find.byKey(
          QaTestKeys.schoolDiscoverySchoolTypeOption(
            SchoolType.highSchool.storageKey,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(QaTestKeys.schoolDiscoveryContinueButton));
      await tester.pumpAndSettle();

      // Step 1 — pick ICSE curriculum.
      await tester.tap(
        find.byKey(
          QaTestKeys.schoolDiscoveryCurriculumOption(
            SchoolCurriculum.icse.storageKey,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(QaTestKeys.schoolDiscoveryContinueButton));
      await tester.pumpAndSettle();

      // Step 2 — toggle the Transport capability (demo default is ON, so this
      // flips it OFF; capability is unlocked because the ceiling is unrestricted).
      await tester.tap(
        find.byKey(QaTestKeys.schoolDiscoveryCapabilityTransport),
      );
      await tester.pump();
      await tester.tap(find.byKey(QaTestKeys.schoolDiscoveryContinueButton));
      await tester.pumpAndSettle();

      // Step 3 — operations model + branch count (defaults are fine), continue.
      await tester.tap(find.byKey(QaTestKeys.schoolDiscoveryContinueButton));
      await tester.pumpAndSettle();

      // Step 4 — review the summary, then apply.
      expect(find.text('School type: High School'), findsOneWidget);
      await tester.tap(find.byKey(QaTestKeys.schoolDiscoveryContinueButton));
      await tester.pump(); // surface the snackbar before the pop animation

      // Applied snackbar surfaced AND the durable configuration reflects the
      // selections made through the wizard.
      expect(
        find.byKey(QaTestKeys.schoolDiscoveryAppliedSnackbar),
        findsWidgets,
      );
      final applied = container.read(schoolConfigurationProvider);
      expect(applied.schoolType, SchoolType.highSchool);
      expect(applied.curriculum, SchoolCurriculum.icse);
      // The capability toggle flowed through into the persisted configuration.
      expect(applied.capabilities.transport, isFalse);

      await tester.pumpAndSettle();
    });
  });
}
