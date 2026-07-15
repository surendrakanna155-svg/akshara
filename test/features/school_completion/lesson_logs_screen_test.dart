import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/school_completion/lesson_logs_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// P1 fix (caps 58-61) — the syllabus daily-capture UI used to write
/// hardcoded demo values ('Grade 8', 'Fractions revision', 'sub_2') and send a
/// FABRICATED `topic_${log.id}` to `completeTopic`, which is not a real
/// `syllabus_topics.id` and fails the completions FK. These widget tests drive
/// the REAL screen end to end (through the actual dialogs, not by calling the
/// repository directly) and assert the topic status change persists in the
/// repository afterwards.
void main() {
  late MockSchoolCompletionRepository repo;

  Widget buildTestApp() {
    repo = MockSchoolCompletionRepository();
    return ProviderScope(
      overrides: [
        schoolCompletionRepositoryProvider.overrideWithValue(repo),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const LessonLogsScreen(),
      ),
    );
  }

  group('LessonLogsScreen', () {
    testWidgets(
        'Log lesson dialog has no hardcoded fields and links a REAL syllabus '
        'topic that persists as completed', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Real class/subject pickers (not text fields with hardcoded values).
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));

      // Select class '7' (matches the seeded 'top_1'/'top_2' syllabus topics
      // for sub_1 — proves the picker drives a REAL, matchable class value).
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Linear equations recap',
      );

      await tester.tap(find.byKey(QaTestKeys.lessonLogCreateSubmitButton));
      await tester.pumpAndSettle();

      // Outcome defaulted to "completed" → the app offers to link a real
      // syllabus topic immediately.
      expect(find.text('Link syllabus topic'), findsOneWidget);
      expect(find.text('Linear equations'), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.lessonLogTopicLinkSubmitButton));
      await tester.pumpAndSettle();

      expect(find.text('Syllabus topic marked complete.'), findsOneWidget);

      // Prove it actually PERSISTED in the repository (not just a snackbar).
      final topics = await repo.listSyllabusTopics(
        query: RepositoryQuery.demo,
        className: '7',
        subjectId: 'sub_1',
      );
      expect(topics.any((t) => t.id == 'top_1' && t.status == 'completed'),
          isTrue);
    });

    testWidgets(
        'Link syllabus topic is honest when no real topic exists for the '
        'class/subject', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Default class ('Nursery') + default subject (English/sub_1) has no
      // seeded syllabus topic — the flow must say so honestly, never fabricate
      // a completion.
      await tester.enterText(
        find.byType(TextFormField).first,
        'Alphabet review',
      );
      await tester.tap(find.byKey(QaTestKeys.lessonLogCreateSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No syllabus topics found'),
        findsOneWidget,
      );
      expect(find.text('Link syllabus topic'), findsNothing);
    });
  });
}
