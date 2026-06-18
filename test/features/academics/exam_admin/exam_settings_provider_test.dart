import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/exams/exam_grading.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/exam_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetExamAdministrationForTest();
  });
  tearDown(() => ExamAdministrationStore.instance.reset());

  test('reads default settings from the store', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = container.read(examReportSettingsProvider);
    expect(settings.gradingScale.name, 'Standard');
    expect(settings.showRankToParents, isFalse);
  });

  test('setGradingScale updates both provider state and the store', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(examReportSettingsProvider.notifier)
        .setGradingScale(ExamGradingScale.cbseScholastic);

    expect(
      container.read(examReportSettingsProvider).gradingScale.name,
      'CBSE (A1–E)',
    );
    expect(
      ExamAdministrationStore.instance.reportSettings.gradingScale.name,
      'CBSE (A1–E)',
    );
  });

  test('rank toggle and term hints flow through to the store', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(examReportSettingsProvider.notifier);
    notifier.setShowRankToParents(true);
    notifier.setSuggestedTerms(const ['Unit Test 1', 'Annual']);

    final stored = ExamAdministrationStore.instance.reportSettings;
    expect(stored.showRankToParents, isTrue);
    expect(stored.suggestedTerms, const ['Unit Test 1', 'Annual']);
  });
}
