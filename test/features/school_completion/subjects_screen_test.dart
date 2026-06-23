import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/school_completion/subjects_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        schoolCompletionRepositoryProvider.overrideWithValue(
          MockSchoolCompletionRepository(),
        ),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const SubjectsScreen(),
      ),
    );
  }

  group('SubjectsScreen', () {
    testWidgets('create dialog adds a subject with real entered values',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.subjectAddButton));
      await tester.pumpAndSettle();

      // The create form is shown (not a hardcoded 'NEW' write).
      expect(find.byKey(QaTestKeys.subjectCreateSubmitButton), findsOneWidget);

      // Create dialog has exactly two text fields: code (0) and name (1).
      await tester.enterText(find.byType(TextFormField).at(0), 'PHY');
      await tester.enterText(find.byType(TextFormField).at(1), 'Physics');
      await tester.tap(find.byKey(QaTestKeys.subjectCreateSubmitButton));
      await tester.pumpAndSettle();

      // The newly created subject appears in the list with its entered values.
      expect(find.text('Physics'), findsOneWidget);
      expect(find.textContaining('PHY'), findsOneWidget);
    });

    testWidgets('create dialog blocks submit when required fields are empty',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.subjectAddButton));
      await tester.pumpAndSettle();

      // Submit with empty fields — validation should keep the dialog open.
      await tester.tap(find.byKey(QaTestKeys.subjectCreateSubmitButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.subjectCreateSubmitButton), findsOneWidget);
      expect(find.text('Enter a subject code'), findsOneWidget);
      expect(find.text('Enter a subject name'), findsOneWidget);
    });

    testWidgets('edit dialog updates an existing subject name', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Seed data has at least one subject; edit the first row.
      await tester.tap(find.byTooltip('Edit subject').first);
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.subjectEditSubmitButton), findsOneWidget);
      // Code field is read-only in the edit form.
      expect(find.text('Subject code cannot be changed'), findsOneWidget);

      // Edit dialog fields: code (read-only, 0) and name (1).
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Renamed Subject',
      );
      await tester.tap(find.byKey(QaTestKeys.subjectEditSubmitButton));
      await tester.pumpAndSettle();

      expect(find.text('Renamed Subject'), findsOneWidget);
    });
  });
}
