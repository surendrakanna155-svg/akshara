import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_marks_progress_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;

  setUp(() async {
    testPrefs = await resetExamAdministrationForTest();
  });

  Widget buildApp({ErpRole role = ErpRole.principal}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesTestOverride(testPrefs),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(role),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ExamMarksProgressScreen(),
      ),
    );
  }

  group('ExamMarksProgressScreen (EXM-2)', () {
    testWidgets('renders a progress card with entered/total + pending count',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Seeded exam_math_8a is in marks_entry with one open slot → one card.
      expect(
        find.byKey(QaTestKeys.examMarksProgressCard('exam_math_8a')),
        findsOneWidget,
      );
      expect(find.text('Unit Test — Mathematics'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      // The open roster shows a pending chip (at least 1 owed).
      expect(find.textContaining('pending'), findsWidgets);
      // The entered/total footer is shown.
      expect(find.textContaining('entered'), findsWidgets);
    });

    testWidgets('a role without exam permissions sees a locked empty state',
        (tester) async {
      await tester.pumpWidget(buildApp(role: ErpRole.parent));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('do not have permission'),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.examMarksProgressCard('exam_math_8a')),
        findsNothing,
      );
    });
  });
}
