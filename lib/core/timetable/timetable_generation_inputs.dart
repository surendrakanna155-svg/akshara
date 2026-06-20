import '../school_config/school_configuration_models.dart';
import '../teaching/teacher_assignment_registry.dart';
import 'class_teacher_assignments.dart';
import 'curriculum_templates.dart';
import 'timetable_generator.dart';

/// One section the mock school schedules.
class MockTimetableSection {
  const MockTimetableSection(this.classLabel, this.grade);
  final String classLabel;
  final int grade;
}

/// The sections the mock app generates a timetable for.
const List<MockTimetableSection> mockTimetableSections = [
  MockTimetableSection('8-A', 8),
  MockTimetableSection('8-B', 8),
];

/// Everything the generator needs for one run.
class TimetableGenerationInputs {
  const TimetableGenerationInputs({
    required this.classes,
    required this.teachers,
    required this.sections,
  });

  final List<GeneratorClass> classes;
  final List<GeneratorTeacher> teachers;
  final List<MockTimetableSection> sections;
}

/// Builds generator inputs from the school's chosen [curriculum].
///
/// Real class teachers (Priya, Mr. Patel, Mrs. Rao) are anchored to the subject
/// they teach so they exist in the roster; the rest of the roster is filled out
/// so every curriculum subject has enough teachers to staff all sections without
/// clashes (two per academic subject, one per room-bound activity — the room is
/// the real limiter there). This keeps the mock's generated timetable complete;
/// the live backend will use real `teacher_subject_assignments` instead.
TimetableGenerationInputs buildMockGenerationInputs({
  required SchoolCurriculum curriculum,
  List<MockTimetableSection> sections = mockTimetableSections,
}) {
  // All distinct subjects needed across the sections, with their room/kind.
  final specByName = <String, CurriculumSubjectSpec>{};
  for (final section in sections) {
    for (final spec in curriculumTemplateFor(curriculum, section.grade)) {
      specByName[spec.subjectName] = spec;
    }
  }

  final teachers = <GeneratorTeacher>[
    // Real teachers anchored to their subject so class teachers are in the pool.
    const GeneratorTeacher(
        id: TeacherAssignmentRegistry.priyaSharmaId,
        name: 'Priya Sharma',
        subjects: {'Mathematics'}),
    const GeneratorTeacher(
        id: TeacherAssignmentRegistry.mrPatelId,
        name: 'Mr. Patel',
        subjects: {'Science'}),
    const GeneratorTeacher(
        id: TeacherAssignmentRegistry.mrsRaoId,
        name: 'Mrs. Rao',
        subjects: {'English'}),
  ];

  int countFor(String subject) =>
      teachers.where((t) => t.subjects.contains(subject)).length;

  String idFor(String subject, int n) {
    final slug = subject
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'tt_${slug}_$n';
  }

  for (final entry in specByName.entries) {
    final subject = entry.key;
    final spec = entry.value;
    final target = spec.isActivity ? 1 : 2;
    var existing = countFor(subject);
    var n = existing + 1;
    while (existing < target) {
      teachers.add(GeneratorTeacher(
        id: idFor(subject, n),
        name: '$subject Teacher $n',
        subjects: {subject},
      ));
      existing += 1;
      n += 1;
    }
  }

  final classes = [
    for (final section in sections)
      GeneratorClass(
        classLabel: section.classLabel,
        grade: section.grade,
        subjects: curriculumTemplateFor(curriculum, section.grade),
        classTeacherId:
            ClassTeacherAssignmentStore.instance.teacherFor(section.classLabel),
      ),
  ];

  return TimetableGenerationInputs(
    classes: classes,
    teachers: teachers,
    sections: sections,
  );
}

/// A teacherId -> display name lookup for the same roster the generator uses,
/// so screens can show "Priya Sharma" instead of a raw id and offer a teacher
/// picker for reassignment.
Map<String, String> mockTimetableTeacherDirectory({
  SchoolCurriculum curriculum = SchoolCurriculum.cbse,
}) {
  final inputs = buildMockGenerationInputs(curriculum: curriculum);
  return {for (final t in inputs.teachers) t.id: t.name};
}
