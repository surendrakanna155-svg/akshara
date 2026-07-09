import 'package:akshara_erp/core/onboarding/tenant_onboarding_store.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_flow_screen.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_models.dart';
import 'package:akshara_erp/features/onboarding/unified_onboarding_provider.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/shared/forms/forms.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-021 (unified onboarding stepper render + Next/Back + final-step
/// submit) and QA-F-022 (AI pre-fill "Generate draft" → loading → mock draft →
/// pre-filled fields). Runs against the demo `MockStartupOnboardingRepository`
/// (deterministic offline draft) + the singleton `TenantOnboardingStore`.

const _demoTenant = 'tenant_demo_001';

Future<void> _pump(WidgetTester tester) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const UnifiedOnboardingFlowScreen(),
      ),
    ),
  );
  // Initial hydration (Future.microtask → repo load) + isLoading clears.
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

/// Scrolls [target] into view within the wizard's ListView before acting on
/// it. The #10 gap-remediation "Ongoing onboarding" card added real height
/// above the Continue/Back/Go-Live row, pushing it beyond the initial
/// viewport + list cache extent on a mobile-sized test surface.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  // The store is a process-wide singleton; reset the demo tenant so each test
  // starts from a clean School Profile step.
  setUp(() => TenantOnboardingStore.instance.reset(_demoTenant));
  tearDown(() => TenantOnboardingStore.instance.reset(_demoTenant));

  group('QA-F-021 · UnifiedOnboardingFlow stepper', () {
    testWidgets('renders step 1 (School Profile) with the stepper', (tester) async {
      await _pump(tester);

      expect(find.byKey(QaTestKeys.unifiedOnboardingScreen), findsOneWidget);
      expect(find.byType(AksharaStepIndicator), findsOneWidget);
      // Step-1 title + the school-profile fields are visible.
      expect(find.text('School setup · School Profile'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.unifiedOnboardingSchoolNameField),
        findsOneWidget,
      );
      // Continue is shown on step 1; Back is not. (Scroll past the #10
      // "Ongoing onboarding" card — the Continue row sits below it.)
      await _scrollTo(tester, find.byKey(QaTestKeys.unifiedOnboardingContinueButton));
      expect(
        find.byKey(QaTestKeys.unifiedOnboardingContinueButton),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Back'), findsNothing);
    });

    testWidgets('Continue advances to step 2 and Back returns to step 1',
        (tester) async {
      await _pump(tester);

      // Fill the school name so the profile step has content, then advance.
      await tester.enterText(
        find.byKey(QaTestKeys.unifiedOnboardingSchoolNameField),
        'Akshara Public School',
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(QaTestKeys.unifiedOnboardingContinueButton));
      await tester.tap(find.byKey(QaTestKeys.unifiedOnboardingContinueButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Now on the Curriculum step.
      expect(find.text('School setup · Curriculum'), findsOneWidget);
      expect(find.text('Board / curriculum'), findsWidgets);

      // Back returns to School Profile.
      await _scrollTo(tester, find.widgetWithText(OutlinedButton, 'Back'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.text('School setup · School Profile'), findsOneWidget);
    });

    testWidgets('final step Go Live submits and surfaces the live success',
        (tester) async {
      await _pump(tester);

      // Seed a complete, go-live-ready config directly so the wizard can reach
      // and pass the final Go Live submit (mirrors what the steps collect).
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(QaTestKeys.unifiedOnboardingScreen)),
      );
      final notifier = container.read(unifiedOnboardingProvider.notifier);
      notifier
        ..updateSchoolName('Akshara Public School')
        ..updateAddress('12 Civic Lane, Bengaluru')
        ..updateContactPhone('9876500001')
        ..updateBoard('CBSE')
        ..updateAcademicYear('2026-27')
        ..updateClasses('Grade 6, Grade 7')
        ..updateSections('A, B')
        ..updateFeeModel('term_wise')
        ..updateFeeCategories('Tuition, Transport')
        ..setStep(UnifiedOnboardingStep.review);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.text('School setup · Review'), findsOneWidget);

      // Go Live → save + goLive resolve → land on the Go Live step.
      await _scrollTo(tester, find.byKey(QaTestKeys.unifiedOnboardingGoLiveButton));
      await tester.tap(find.byKey(QaTestKeys.unifiedOnboardingGoLiveButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.unifiedOnboardingGoLiveSuccess),
        findsOneWidget,
      );
      expect(find.textContaining('School is live'), findsOneWidget);
    });
  });

  group('QA-F-022 · UnifiedOnboardingFlow AI pre-fill', () {
    testWidgets('Generate draft opens the brief sheet, runs, and pre-fills fields',
        (tester) async {
      await _pump(tester);

      // Open the AI brief bottom sheet.
      expect(
        find.byKey(QaTestKeys.unifiedOnboardingAiPrefillButton),
        findsOneWidget,
      );
      await tester.tap(find.byKey(QaTestKeys.unifiedOnboardingAiPrefillButton));
      await tester.pumpAndSettle();

      // Brief sheet is open; provide a school name + grade range. The wizard's
      // own "School name" field is also in the tree, so scope finds to the
      // modal bottom sheet subtree.
      expect(find.text('Tell us about your school'), findsOneWidget);
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(TextField, 'School name'),
        ),
        'Sunrise Vidyalaya',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Lowest grade'),
        'Grade 1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Highest grade'),
        'Grade 5',
      );
      await tester.pump();

      // Tap "Generate draft" → sheet closes, aiPrefill runs (loading → done).
      await tester.tap(
        find.byKey(QaTestKeys.unifiedOnboardingAiPrefillApplyButton),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Mock deterministic draft applied → success snackbar surfaces and the
      // school name pre-fills into the wizard (proves the draft reached state).
      expect(find.textContaining('Draft applied'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(QaTestKeys.unifiedOnboardingScreen)),
      );
      final state = container.read(unifiedOnboardingProvider);
      expect(state.schoolName, 'Sunrise Vidyalaya');
      expect(state.classes, contains('Grade 1'));
      expect(state.classes, contains('Grade 5'));
    });
  });

  group('#10 gap-remediation · ongoing onboarding actions are reachable', () {
    // OnboardingHubScreen (/sis/onboarding, invites + student import) and
    // StudentOnboardingScreen (/admin/onboarding/students) were registered
    // routes with NO nav entry anywhere in the app. This wizard is the one
    // screen with a real, live entry point (Settings → "Guided school
    // onboarding"), so its "Ongoing onboarding" card is where the fix wires a
    // real path to both — proven here via a minimal real GoRouter.
    testWidgets(
        'the Ongoing onboarding card is visible on step 1 and routes to both targets',
        (tester) async {
      TenantOnboardingStore.instance.reset(_demoTenant);
      addTearDown(() => TenantOnboardingStore.instance.reset(_demoTenant));

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const UnifiedOnboardingFlowScreen(),
          ),
          GoRoute(
            path: RouteNames.onboardingHub,
            builder: (context, state) =>
                const Scaffold(body: Text('Onboarding hub reached')),
          ),
          GoRoute(
            path: RouteNames.studentOnboarding,
            builder: (context, state) =>
                const Scaffold(body: Text('Student onboarding reached')),
          ),
        ],
      );

      useMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides(),
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.text('Ongoing onboarding'), findsOneWidget);
      expect(
        find.text('Invite parents, teachers & students'),
        findsOneWidget,
      );
      expect(find.text('Import / add students'), findsOneWidget);

      await tester.tap(find.text('Invite parents, teachers & students'));
      await tester.pumpAndSettle();
      expect(find.text('Onboarding hub reached'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import / add students'));
      await tester.pumpAndSettle();
      expect(find.text('Student onboarding reached'), findsOneWidget);
    });
  });
}
