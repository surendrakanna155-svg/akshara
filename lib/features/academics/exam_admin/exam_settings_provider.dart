import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/exams/exam_grading.dart';

/// Per-school exam report settings (grading scale, rank visibility, term hints),
/// backed by the [ExamAdministrationStore] singleton so changes persist and are
/// applied at publish time.
final examReportSettingsProvider =
    NotifierProvider<ExamReportSettingsNotifier, ExamReportSettings>(
  ExamReportSettingsNotifier.new,
);

class ExamReportSettingsNotifier extends Notifier<ExamReportSettings> {
  @override
  ExamReportSettings build() {
    final store = ExamAdministrationStore.instance;
    store.ensureSeeded();
    return store.reportSettings;
  }

  /// Swaps the board grading scale (Standard / CBSE / Percentage-Division …).
  void setGradingScale(ExamGradingScale scale) =>
      _apply(state.copyWith(gradingScale: scale));

  /// Turns rank visibility for parents/students on or off (school decision).
  void setShowRankToParents(bool value) =>
      _apply(state.copyWith(showRankToParents: value));

  /// Updates the quick-pick term-name hints offered when creating an exam.
  void setSuggestedTerms(List<String> terms) =>
      _apply(state.copyWith(suggestedTerms: terms));

  void _apply(ExamReportSettings next) {
    ExamAdministrationStore.instance.configureReportSettings(next);
    state = next;
  }
}
