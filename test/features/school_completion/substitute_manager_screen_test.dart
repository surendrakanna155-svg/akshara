import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/school_completion/substitute_manager_screen.dart';
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
        home: SubstituteManagerScreen(),
      ),
    );
  }

  group('SubstituteManagerScreen', () {
    testWidgets('renders open slots and wizard labels', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Substitute Teacher Wizard'), findsOneWidget);
      expect(find.text('Open slots'), findsOneWidget);
      expect(find.text('Available teachers'), findsOneWidget);
      expect(find.text('Select slot'), findsOneWidget);
      expect(find.text('Select teacher'), findsOneWidget);
      expect(find.text('Confirm and notify'), findsOneWidget);
    });

    testWidgets('slot and teacher selection updates wizard', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final slotFinder = find.byKey(const ValueKey('substitute_slot_slot_1'));
      await tester.ensureVisible(slotFinder);
      await tester.tap(slotFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Selected'), findsWidgets);

      final teacherSelectFinder = find.byKey(
        const ValueKey('substitute_teacher_select_teacher_2'),
      );
      await tester.ensureVisible(teacherSelectFinder);
      await tester.tap(teacherSelectFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Assign substitute'), findsOneWidget);
    });
  });
}
