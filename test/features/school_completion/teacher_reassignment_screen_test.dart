import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/school_completion/teacher_reassignment_screen.dart';
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
      child: const MaterialApp(
        home: TeacherReassignmentScreen(),
      ),
    );
  }

  group('TeacherReassignmentScreen', () {
    testWidgets('renders 3-step reassignment wizard', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Teacher Reassignment Wizard'), findsOneWidget);
      expect(find.text('Step 1: Select periods'), findsOneWidget);
      expect(find.text('Step 2: Select target teacher'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.teacherReassignmentSourceFilter),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('teacher_reassignment_select_teacher_2')),
        findsOneWidget,
      );
    });

    testWidgets('selecting periods and teacher enables submit action',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      final selectTarget = find.byKey(
        const ValueKey('teacher_reassignment_select_teacher_2'),
      );
      await tester.ensureVisible(selectTarget);
      await tester.tap(selectTarget, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Reassign teacher'), findsOneWidget);
    });
  });
}
