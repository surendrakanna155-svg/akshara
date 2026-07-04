import 'package:akshara_erp/core/reliability/reliability_providers.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_marks_entry_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

/// REL-3 — the marks grid autosaves a debounced draft as a teacher types, and
/// offers to resume it on the next visit (WhatsApp-draft UX), so a half-entered
/// roster is never lost to a phone-lock / app-switch / kill.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  // Shared across both "sessions" so the draft survives a screen rebuild — the
  // real app persists the store durably; the in-memory store stands in here.
  late InMemoryReliabilityStore sharedStore;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
    sharedStore = InMemoryReliabilityStore();
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.principal),
        ),
        reliabilityStoreProvider.overrideWithValue(sharedStore),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ExamMarksEntryScreen(examId: 'exam_math_8a'),
      ),
    );
  }

  testWidgets(
      'REL-3: typing a mark autosaves a draft that is re-offered and resumed '
      'on the next visit', (tester) async {
    // ── Session 1: teacher types a mark into the open (unentered) row. ──
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    const openMarkId = 'exam_math_8a_06'; // seeded unentered row
    final openField = find.byKey(QaTestKeys.examAdminMarkField(openMarkId));
    await tester.scrollUntilVisible(
      openField,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(openField, '37');

    // Let the autosave debounce (800ms) elapse and the async save complete.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // ── Session 2: fully unmount, then rebuild a fresh screen over the SAME
    // store (simulates re-opening the screen / app restart) → it offers resume.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Resume where you left off'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Resume'));
    await tester.pumpAndSettle();

    // The typed-but-unsaved mark is restored into the row (even though it was
    // below the fold — the resumed value rehydrates the row when built).
    final openFieldAgain =
        find.byKey(QaTestKeys.examAdminMarkField(openMarkId));
    await tester.scrollUntilVisible(
      openFieldAgain,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(openFieldAgain).controller!.text,
      '37',
    );
  });

  testWidgets('REL-3: discarding the resume banner drops the draft',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    const openMarkId = 'exam_math_8a_06';
    final openField = find.byKey(QaTestKeys.examAdminMarkField(openMarkId));
    await tester.scrollUntilVisible(
      openField,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(openField, '44');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Fresh session → Discard the offered draft.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Resume where you left off'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    // A third session sees no draft — it was cleared.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Resume where you left off'), findsNothing);
  });
}
