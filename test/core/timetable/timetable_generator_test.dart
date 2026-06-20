import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/timetable/curriculum_templates.dart';
import 'package:akshara_erp/core/timetable/timetable_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A small, well-staffed school used by most tests.
  final teachers = <GeneratorTeacher>[
    const GeneratorTeacher(
        id: 't_math', name: 'Maths Sir', subjects: {'Mathematics'}),
    const GeneratorTeacher(
        id: 't_sci', name: 'Science Miss', subjects: {'Science', 'EVS'}),
    const GeneratorTeacher(
        id: 't_eng', name: 'English Miss', subjects: {'English'}),
    const GeneratorTeacher(
        id: 't_soc', name: 'Social Sir', subjects: {'Social Science'}),
    const GeneratorTeacher(
        id: 't_lang', name: 'Hindi Sir', subjects: {'Hindi', 'Telugu'}),
    const GeneratorTeacher(
        id: 't_pe', name: 'PE Coach', subjects: {'Physical Education'}),
    const GeneratorTeacher(
        id: 't_comp', name: 'Computer Miss', subjects: {'Computer'}),
    const GeneratorTeacher(
        id: 't_lib', name: 'Librarian', subjects: {'Library'}),
  ];

  GeneratorClass classFor(String label, int grade, String? ctId) =>
      GeneratorClass(
        classLabel: label,
        grade: grade,
        subjects: curriculumTemplateFor(SchoolCurriculum.cbse, grade),
        classTeacherId: ctId,
      );

  test('every section gets period 1 as the class teacher period', () {
    final result = generateTimetable(
      classes: [classFor('8-A', 8, 't_math')],
      teachers: teachers,
    );

    final firstPeriods =
        result.forClass('8-A').where((p) => p.period == 1).toList();
    expect(firstPeriods, isNotEmpty);
    for (final p in firstPeriods) {
      expect(p.isClassTeacherPeriod, isTrue);
      expect(p.teacherId, 't_math');
    }
  });

  test('class teacher who teaches a needed subject uses it in period 1', () {
    final result = generateTimetable(
      classes: [classFor('8-A', 8, 't_math')],
      teachers: teachers,
    );
    final firstMonday =
        result.forClass('8-A').firstWhere((p) => p.day == 1 && p.period == 1);
    // Maths Sir is class teacher and Maths is in the grade-8 curriculum.
    expect(firstMonday.subject, 'Mathematics');
  });

  test('class teacher with no matching subject gets a homeroom period', () {
    // A class teacher whose only subject is not in the curriculum -> homeroom.
    final extraTeachers = [
      ...teachers,
      const GeneratorTeacher(
          id: 't_music', name: 'Music Sir', subjects: {'Music'}),
    ];
    final result = generateTimetable(
      classes: [classFor('8-A', 8, 't_music')],
      teachers: extraTeachers,
    );
    final firstMonday =
        result.forClass('8-A').firstWhere((p) => p.day == 1 && p.period == 1);
    expect(firstMonday.isClassTeacherPeriod, isTrue);
    expect(firstMonday.teacherId, 't_music');
    expect(firstMonday.subject, 'Class Teacher Period');
  });

  test('no class teacher set produces a warning', () {
    final result = generateTimetable(
      classes: [classFor('8-A', 8, null)],
      teachers: teachers,
    );
    expect(
      result.warnings.any((w) => w.contains('no class teacher')),
      isTrue,
    );
  });

  test('a teacher is never double-booked across classes in the same slot', () {
    final result = generateTimetable(
      classes: [
        classFor('8-A', 8, 't_math'),
        classFor('8-B', 8, 't_eng'),
        classFor('9-A', 9, 't_sci'),
      ],
      teachers: teachers,
    );

    final seen = <String>{};
    for (final p in result.periods) {
      final id = p.teacherId;
      if (id == null || id.isEmpty) continue;
      final key = '$id|${p.day}|${p.period}';
      expect(seen.contains(key), isFalse,
          reason: 'teacher $id double-booked at day ${p.day} period ${p.period}');
      seen.add(key);
    }
  });

  test('a shared room hosts only one class per slot', () {
    final result = generateTimetable(
      classes: [
        classFor('8-A', 8, 't_math'),
        classFor('8-B', 8, 't_eng'),
        classFor('9-A', 9, 't_sci'),
      ],
      teachers: teachers,
    );

    final seen = <String>{};
    for (final p in result.periods) {
      if (p.room == null) continue;
      final key = '${p.room}|${p.day}|${p.period}';
      expect(seen.contains(key), isFalse,
          reason: '${p.room} double-booked at day ${p.day} period ${p.period}');
      seen.add(key);
    }
  });

  test('every slot in the grid is filled (subject or free)', () {
    const periodsPerDay = 7;
    const daysPerWeek = 6;
    final result = generateTimetable(
      classes: [classFor('8-A', 8, 't_math')],
      teachers: teachers,
      periodsPerDay: periodsPerDay,
      daysPerWeek: daysPerWeek,
    );
    expect(result.forClass('8-A'), hasLength(periodsPerDay * daysPerWeek));
  });

  test('a subject with no qualified teacher is reported, not crashed', () {
    // Only a maths teacher exists; everything else is unstaffable.
    final result = generateTimetable(
      classes: [classFor('8-A', 8, 't_math')],
      teachers: const [
        GeneratorTeacher(
            id: 't_math', name: 'Maths Sir', subjects: {'Mathematics'}),
      ],
    );
    // Maths gets placed; other subjects fall to free slots + warnings.
    expect(result.warnings, isNotEmpty);
    expect(
      result.forClass('8-A').any((p) => p.subject == 'Mathematics'),
      isTrue,
    );
    expect(result.forClass('8-A').any((p) => p.isFree), isTrue);
  });

  test('placed periods only use teachers qualified for the subject', () {
    final result = generateTimetable(
      classes: [classFor('8-A', 8, 't_math'), classFor('9-B', 9, 't_eng')],
      teachers: teachers,
    );
    final byId = {for (final t in teachers) t.id: t};
    for (final p in result.periods) {
      if (p.isFree || p.subject == 'Class Teacher Period') continue;
      final t = byId[p.teacherId];
      expect(t, isNotNull);
      expect(t!.subjects.contains(p.subject), isTrue,
          reason: '${t.name} cannot teach ${p.subject}');
    }
  });
}
