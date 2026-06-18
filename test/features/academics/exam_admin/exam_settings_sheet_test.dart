import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_grading.dart';
import 'package:akshara_erp/features/academics/exam_admin/widgets/exam_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/exam_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    prefs = await resetExamAdministrationForTest();
  });
  tearDown(() => ExamAdministrationStore.instance.reset());

  Widget host() => ProviderScope(
        overrides: [sharedPreferencesTestOverride(prefs)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ExamSettingsPanel()),
          ),
        ),
      );

  testWidgets('selecting a board scale updates the store', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final cbseTile = find.byKey(
      ValueKey('exam_scale_${ExamGradingScale.cbseScholastic.name}'),
    );
    await tester.ensureVisible(cbseTile);
    await tester.tap(cbseTile);
    await tester.pumpAndSettle();

    expect(
      ExamAdministrationStore.instance.reportSettings.gradingScale.name,
      'CBSE (A1–E)',
    );
  });

  testWidgets('rank toggle updates the store', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final rank = find.byKey(const Key('exam_settings_rank_switch'));
    await tester.ensureVisible(rank);
    await tester.tap(rank);
    await tester.pumpAndSettle();

    expect(
      ExamAdministrationStore.instance.reportSettings.showRankToParents,
      isTrue,
    );
  });

  testWidgets('entering term hints and tapping Done saves them', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('exam_settings_terms_field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Unit Test 1, Half-Yearly, Annual');

    final done = find.byKey(const Key('exam_settings_save_button'));
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(
      ExamAdministrationStore.instance.reportSettings.suggestedTerms,
      const ['Unit Test 1', 'Half-Yearly', 'Annual'],
    );
  });
}
