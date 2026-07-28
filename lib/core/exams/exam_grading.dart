/// Per-school, board-aware exam grading & report configuration.
///
/// Owner decisions (2026-06-18, see docs/EXAMS_BUILD_PLAN.md):
///   * Report cards show BOTH marks/percentage AND a letter grade.
///   * Rank visibility is a per-school setting (computed always; shown to
///     parents only if the school enables it).
///   * Exam terms are fully flexible (free text) — presets are only hints.
///
/// Schools follow different boards (CBSE / State / ICSE) which grade
/// differently, so the grading scale is data, not hardcoded. The default
/// ([ExamGradingScale.standard]) reproduces the previous fixed scale exactly,
/// so existing behaviour is unchanged until a school picks a different scale.
library;

/// One row of a grading scale: any percentage `>= minPercent` earns [label].
class GradeBand {
  const GradeBand(this.minPercent, this.label);

  /// Inclusive lower bound (0–100).
  final double minPercent;

  /// Letter/word grade awarded at or above [minPercent] (e.g. 'A1', 'First').
  final String label;
}

/// An ordered set of [GradeBand]s (highest threshold first) that converts a
/// percentage into a grade label.
class ExamGradingScale {
  const ExamGradingScale({required this.name, required this.bands});

  final String name;

  /// Bands sorted by descending [GradeBand.minPercent].
  final List<GradeBand> bands;

  /// Grade label for [percent] (0–100). Falls back to the lowest band.
  String gradeFor(double percent) {
    for (final band in bands) {
      if (percent >= band.minPercent) return band.label;
    }
    return bands.isEmpty ? '-' : bands.last.label;
  }

  /// Default scale — identical thresholds to the legacy fixed grading.
  /// (>=90 A+, >=80 A, >=70 B+, >=60 B, >=50 C, else D.)
  static const ExamGradingScale standard = ExamGradingScale(
    name: 'Standard',
    bands: [
      GradeBand(90, 'A+'),
      GradeBand(80, 'A'),
      GradeBand(70, 'B+'),
      GradeBand(60, 'B'),
      GradeBand(50, 'C'),
      GradeBand(0, 'D'),
    ],
  );

  /// CBSE-style scholastic grades (starting point — schools can refine).
  static const ExamGradingScale cbseScholastic = ExamGradingScale(
    name: 'CBSE (A1–E)',
    bands: [
      GradeBand(91, 'A1'),
      GradeBand(81, 'A2'),
      GradeBand(71, 'B1'),
      GradeBand(61, 'B2'),
      GradeBand(51, 'C1'),
      GradeBand(41, 'C2'),
      GradeBand(33, 'D'),
      GradeBand(0, 'E'),
    ],
  );

  /// Percentage / division style common in many State boards.
  static const ExamGradingScale percentageDivision = ExamGradingScale(
    name: 'Percentage / Division',
    bands: [
      GradeBand(75, 'Distinction'),
      GradeBand(60, 'First'),
      GradeBand(50, 'Second'),
      GradeBand(35, 'Third'),
      GradeBand(0, 'Fail'),
    ],
  );

  /// AP / Telangana State Board (SSC) 10-point grading.
  ///
  /// The State Board ladder looks superficially like CBSE's A1–E but the
  /// thresholds are NOT the same (A1 starts at 92 here vs 91 for CBSE, and every
  /// band below differs), so a State-Board school publishing on the CBSE preset
  /// would print wrong grades on real report cards. Kept as its own preset
  /// rather than reusing [cbseScholastic].
  ///
  /// Bands map to grade points 10 → 4 (A1=10, A2=9, B1=8, B2=7, C1=6, C2=5,
  /// D=4), with E as the fail band below 35.
  static const ExamGradingScale stateBoardSsc = ExamGradingScale(
    name: 'State Board — SSC (A1–E)',
    bands: [
      GradeBand(92, 'A1'),
      GradeBand(83, 'A2'),
      GradeBand(75, 'B1'),
      GradeBand(67, 'B2'),
      GradeBand(59, 'C1'),
      GradeBand(51, 'C2'),
      GradeBand(35, 'D'),
      GradeBand(0, 'E'),
    ],
  );

  /// Built-in presets a school can choose from (and later customise).
  static const List<ExamGradingScale> presets = [
    standard,
    cbseScholastic,
    stateBoardSsc,
    percentageDivision,
  ];
}

/// Per-school report settings applied when results are published.
class ExamReportSettings {
  const ExamReportSettings({
    this.gradingScale = ExamGradingScale.standard,
    this.showRankToParents = false,
    this.suggestedTerms = const [],
  });

  /// Board-aware grading scale used to derive letter grades.
  final ExamGradingScale gradingScale;

  /// Whether class/section rank is shown to parents & students.
  /// Rank is always computed for the school's own use regardless of this flag.
  final bool showRankToParents;

  /// Optional term-name hints for the setup screen. Terms remain free text.
  final List<String> suggestedTerms;

  /// Safe default — preserves legacy behaviour (standard scale, rank hidden).
  factory ExamReportSettings.standard() => const ExamReportSettings();

  ExamReportSettings copyWith({
    ExamGradingScale? gradingScale,
    bool? showRankToParents,
    List<String>? suggestedTerms,
  }) {
    return ExamReportSettings(
      gradingScale: gradingScale ?? this.gradingScale,
      showRankToParents: showRankToParents ?? this.showRankToParents,
      suggestedTerms: suggestedTerms ?? this.suggestedTerms,
    );
  }
}
