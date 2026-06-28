import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/platform/organization_builder/organization_builder_interview_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_test_overrides.dart';
import '../../../test_helpers.dart';

/// Parent session — lacks the manageOrganizationBuilder permission.
Override _parentAuthOverride() => authStateOverride(
      const AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '8888888888',
        displayName: 'QW3 Parent',
        role: UserRole.parent,
      ).copyWith(claims: AuthClaims.demoForRole(erpRole: ErpRole.parent)),
    );

/// QW3 · QA-F-059 — Organization Builder interview field render + Next gating.
/// `organization_builder_interview_screen.dart` was 0% lcov / never pumped. This
/// covers the 7-step interview: identity field render, hydration of an existing
/// demo draft, and the Continue gate (advance only after the save mutation
/// succeeds; disabled while the save is in flight). The save mutation is
/// permission-gated (`manageOrganizationBuilder`) — exercised via the QA
/// super-admin role matrix.
Future<void> _pump(
  WidgetTester tester, {
  required String draftId,
  required String packId,
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      // QA-login env → superAdmin maps to the full permission matrix, so the
      // permission-gated save mutation is allowed to run (mirrors prod QA path).
      overrides: erpWidgetTestOverrides([
        environmentProvider.overrideWith(
          (ref) => Environment.development.copyWith(enableQaLogin: true),
        ),
        ...overrides,
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: OrganizationBuilderInterviewScreen(
          draftId: draftId,
          packId: packId,
        ),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-059 · OrganizationBuilderInterviewScreen', () {
    testWidgets('renders the identity step with the name field + Continue',
        (tester) async {
      // Fresh draft id → demo repo returns a blank step-0 school draft.
      await _pump(tester, draftId: 'draft_qw3_new', packId: 'pack_school');

      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewScreen),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewContinueButton),
        findsOneWidget,
      );
    });

    testWidgets('hydrates an existing draft to its saved step', (tester) async {
      // draft_existing_1 is a salon draft saved at step 3 (Workflows).
      await _pump(
        tester,
        draftId: 'draft_existing_1',
        packId: 'pack_salon',
      );

      // Hydrated past identity → the Workflows field is shown, not the name field.
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewWorkflowsField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
        findsNothing,
      );
      // A Back button appears once past the first step.
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewBackButton),
        findsOneWidget,
      );
    });

    testWidgets('Continue advances to the Scale step after the save succeeds',
        (tester) async {
      await _pump(tester, draftId: 'draft_qw3_advance', packId: 'pack_school');

      // Step 0 (Identity) → enter the school name.
      await tester.enterText(
        find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
        'QW3 Test School',
      );
      await tester.tap(
        find.byKey(QaTestKeys.organizationBuilderInterviewContinueButton),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // The save mutation succeeded → advanced to step 1 (Scale): the
      // primary-scale field is now visible, the identity field is gone.
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewScalePrimaryField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
        findsNothing,
      );
    });

    testWidgets('Continue is blocked when the manage permission is absent',
        (tester) async {
      // Parent role lacks manageOrganizationBuilder → the save mutation throws,
      // so the wizard must NOT advance past the identity step.
      await _pump(
        tester,
        draftId: 'draft_qw3_denied',
        packId: 'pack_school',
        overrides: [_parentAuthOverride()],
      );

      await tester.enterText(
        find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
        'Denied School',
      );
      await tester.tap(
        find.byKey(QaTestKeys.organizationBuilderInterviewContinueButton),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Still on the identity step — gating held.
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewNameField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.organizationBuilderInterviewScalePrimaryField),
        findsNothing,
      );
    });
  });
}
