import '../school_config/school_configuration_models.dart';

/// Grade-appropriate curriculum templates.
///
/// When a school finishes setup it has already chosen its [SchoolCurriculum]
/// (CBSE / ICSE / State Board / …). Given that choice and a grade number this
/// catalog proposes the subjects that grade should study and how many periods a
/// week each one needs. The school can still edit the result — these are smart
/// starting points, not hard rules.
///
/// Grade bands follow real schooling:
///  * Grades 1–5 (lower primary): one combined **EVS / General Science** — there
///    is no Physics / Chemistry / Biology split.
///  * Grades 6–8 (middle): a single combined **Science** plus **Social Science**.
///  * Grades 9–10 (secondary): heavier Science / Maths / Social load.
///
/// Activities (Games, Computer, Library, Art) are modelled as subjects with a
/// small weekly count and, when relevant, a [requiresRoom] so the timetable
/// generator never books two classes into the one computer lab or playground at
/// the same time.

/// How a subject behaves in the timetable.
enum CurriculumSubjectKind {
  /// A regular academic subject (Maths, Science, a language).
  core,

  /// A non-daily activity (Games, Computer, Library, Art).
  activity,
}

/// One subject in a grade's proposed curriculum.
class CurriculumSubjectSpec {
  const CurriculumSubjectSpec({
    required this.subjectName,
    required this.periodsPerWeek,
    this.kind = CurriculumSubjectKind.core,
    this.requiresRoom,
  });

  final String subjectName;
  final int periodsPerWeek;
  final CurriculumSubjectKind kind;

  /// A shared facility this subject must run in (e.g. 'Computer Lab',
  /// 'Playground', 'Library'). Null for ordinary classroom subjects.
  final String? requiresRoom;

  bool get isActivity => kind == CurriculumSubjectKind.activity;

  @override
  String toString() =>
      'CurriculumSubjectSpec($subjectName, $periodsPerWeek/wk, ${kind.name}'
      '${requiresRoom == null ? '' : ', room=$requiresRoom'})';
}

/// The three schooling stages used to shape the subject list.
enum GradeBand { lowerPrimary, middle, secondary }

/// Lower primary = 1–5, middle = 6–8, secondary = 9–10 (and above, treated the
/// same here). Anything below 1 is clamped to lower primary.
GradeBand gradeBandFor(int grade) {
  if (grade <= 5) return GradeBand.lowerPrimary;
  if (grade <= 8) return GradeBand.middle;
  return GradeBand.secondary;
}

/// The proposed weekly subjects for a [grade] under the given [curriculum].
List<CurriculumSubjectSpec> curriculumTemplateFor(
  SchoolCurriculum curriculum,
  int grade,
) {
  final band = gradeBandFor(grade);
  final languages = _languagesFor(curriculum, band);

  // Shared activities across all bands (room-aware). Counts are light so they
  // sit alongside the academic load without crowding it.
  const activities = <CurriculumSubjectSpec>[
    CurriculumSubjectSpec(
      subjectName: 'Physical Education',
      periodsPerWeek: 2,
      kind: CurriculumSubjectKind.activity,
      requiresRoom: 'Playground',
    ),
    CurriculumSubjectSpec(
      subjectName: 'Computer',
      periodsPerWeek: 2,
      kind: CurriculumSubjectKind.activity,
      requiresRoom: 'Computer Lab',
    ),
    CurriculumSubjectSpec(
      subjectName: 'Library',
      periodsPerWeek: 1,
      kind: CurriculumSubjectKind.activity,
      requiresRoom: 'Library',
    ),
  ];

  switch (band) {
    case GradeBand.lowerPrimary:
      return [
        for (final lang in languages)
          CurriculumSubjectSpec(subjectName: lang, periodsPerWeek: 6),
        const CurriculumSubjectSpec(
            subjectName: 'Mathematics', periodsPerWeek: 6),
        // One combined environmental/general-science subject — NO split.
        const CurriculumSubjectSpec(
            subjectName: 'Environmental Studies (EVS)', periodsPerWeek: 5),
        const CurriculumSubjectSpec(
            subjectName: 'General Knowledge', periodsPerWeek: 2),
        const CurriculumSubjectSpec(
          subjectName: 'Art & Craft',
          periodsPerWeek: 2,
          kind: CurriculumSubjectKind.activity,
        ),
        ...activities,
      ];

    case GradeBand.middle:
      return [
        for (final lang in languages)
          CurriculumSubjectSpec(subjectName: lang, periodsPerWeek: 5),
        const CurriculumSubjectSpec(
            subjectName: 'Mathematics', periodsPerWeek: 6),
        // Single combined Science for middle grades.
        const CurriculumSubjectSpec(subjectName: 'Science', periodsPerWeek: 6),
        const CurriculumSubjectSpec(
            subjectName: 'Social Science', periodsPerWeek: 5),
        ...activities,
      ];

    case GradeBand.secondary:
      return [
        for (final lang in languages)
          CurriculumSubjectSpec(subjectName: lang, periodsPerWeek: 5),
        const CurriculumSubjectSpec(
            subjectName: 'Mathematics', periodsPerWeek: 7),
        const CurriculumSubjectSpec(subjectName: 'Science', periodsPerWeek: 7),
        const CurriculumSubjectSpec(
            subjectName: 'Social Science', periodsPerWeek: 6),
        ...activities,
      ];
  }
}

/// The languages a board teaches at a given band. State boards run the regional
/// language; CBSE adds Sanskrit as a third language in the middle grades.
List<String> _languagesFor(SchoolCurriculum curriculum, GradeBand band) {
  switch (curriculum) {
    case SchoolCurriculum.stateBoard:
      return const ['Telugu', 'Hindi', 'English'];
    case SchoolCurriculum.cbse:
      return band == GradeBand.middle
          ? const ['English', 'Hindi', 'Sanskrit']
          : const ['English', 'Hindi'];
    case SchoolCurriculum.icse:
      return const ['English', 'Hindi'];
    case SchoolCurriculum.ib:
    case SchoolCurriculum.cambridge:
    case SchoolCurriculum.custom:
      return const ['English', 'Second Language'];
  }
}

/// Total weekly periods the proposed template needs — useful to check it fits
/// the school's "periods per day × days per week" before generating.
int curriculumWeeklyLoad(SchoolCurriculum curriculum, int grade) {
  var total = 0;
  for (final spec in curriculumTemplateFor(curriculum, grade)) {
    total += spec.periodsPerWeek;
  }
  return total;
}
