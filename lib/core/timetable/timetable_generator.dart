import 'curriculum_templates.dart';

/// Rule-based weekly timetable generator.
///
/// Given the school's classes (each with its grade-appropriate subject list from
/// [curriculumTemplateFor]), the teachers and what they teach, and one class
/// teacher per section, this builds a full fixed weekly grid in plain code — no
/// AI. The result is a starting timetable the coordinator/principal then tweaks;
/// the daily leave-substitution engine runs on top of it.
///
/// Rules honoured:
///  * **Period 1 of every section is its class teacher's period** — the class
///    teacher is there to take attendance. If the class teacher also teaches a
///    subject this class needs, that subject fills period 1; otherwise it is a
///    short homeroom/"Class Teacher Period".
///  * A teacher is never double-booked (same day + period in two classes).
///  * A shared room (Computer Lab, Playground, Library) hosts one class at a
///    time.
///  * Activities run their weekly count (e.g. Games twice, Library once).
///  * A subject is spread across the week rather than stacked on one day where
///    possible.
///
/// When something cannot be placed (no free qualified teacher, not enough slots)
/// the slot is left free and a plain-language warning is recorded so a human can
/// fix it — the generator never silently drops demand.

/// A teacher available to the generator.
class GeneratorTeacher {
  const GeneratorTeacher({
    required this.id,
    required this.name,
    this.subjects = const {},
  });

  final String id;
  final String name;

  /// Subject names this teacher can take (e.g. {'Mathematics', 'Science'}).
  final Set<String> subjects;
}

/// One section to schedule.
class GeneratorClass {
  const GeneratorClass({
    required this.classLabel,
    required this.grade,
    required this.subjects,
    this.classTeacherId,
  });

  /// e.g. '8-A'.
  final String classLabel;
  final int grade;

  /// The grade's curriculum (usually from [curriculumTemplateFor]).
  final List<CurriculumSubjectSpec> subjects;

  /// The teacher who owns period 1 / takes attendance. Null = not set yet.
  final String? classTeacherId;
}

/// One scheduled cell in the generated grid.
class GeneratedPeriod {
  const GeneratedPeriod({
    required this.classLabel,
    required this.day,
    required this.period,
    required this.subject,
    this.teacherId,
    this.teacherName,
    this.room,
    this.isClassTeacherPeriod = false,
    this.isFree = false,
  });

  final String classLabel;

  /// 1-based day of week (1 = Monday).
  final int day;

  /// 1-based period number within the day.
  final int period;

  final String subject;
  final String? teacherId;
  final String? teacherName;

  /// Shared facility used, if any.
  final String? room;

  /// True for the class teacher's reserved first period.
  final bool isClassTeacherPeriod;

  /// True when nothing could be scheduled here (an empty/free slot).
  final bool isFree;

  bool get isUnstaffed => !isFree && (teacherId == null || teacherId!.isEmpty);
}

/// The output of a generation run.
class GeneratedTimetable {
  const GeneratedTimetable({required this.periods, required this.warnings});

  final List<GeneratedPeriod> periods;

  /// Plain-language notes about anything that could not be placed.
  final List<String> warnings;

  List<GeneratedPeriod> forClass(String classLabel) =>
      periods.where((p) => p.classLabel == classLabel).toList();
}

/// Builds the weekly timetable. Pure and deterministic.
GeneratedTimetable generateTimetable({
  required List<GeneratorClass> classes,
  required List<GeneratorTeacher> teachers,
  int periodsPerDay = 7,
  int daysPerWeek = 6,
}) {
  final teacherById = {for (final t in teachers) t.id: t};
  // 'teacherId|day|period' and 'room|day|period' occupancy across all classes.
  final teacherBusy = <String>{};
  final roomBusy = <String>{};

  final out = <GeneratedPeriod>[];
  final warnings = <String>[];

  String tKey(String id, int d, int p) => '$id|$d|$p';
  String rKey(String room, int d, int p) => '$room|$d|$p';

  bool teacherFree(String id, int d, int p) => !teacherBusy.contains(tKey(id, d, p));
  bool roomFree(String? room, int d, int p) =>
      room == null || !roomBusy.contains(rKey(room, d, p));

  for (final cls in classes) {
    // Remaining periods to place, per subject (spec carries room + name).
    final remaining = <String, int>{};
    final specByName = <String, CurriculumSubjectSpec>{};
    for (final s in cls.subjects) {
      remaining[s.subjectName] = (remaining[s.subjectName] ?? 0) + s.periodsPerWeek;
      specByName[s.subjectName] = s;
    }

    // Per-class grid + per-day subject usage (for spreading).
    final grid = <GeneratedPeriod?>[
      for (var i = 0; i < daysPerWeek * periodsPerDay; i++) null,
    ];
    int idx(int d, int p) => (d - 1) * periodsPerDay + (p - 1);
    final usedSubjectToday = <int, Set<String>>{
      for (var d = 1; d <= daysPerWeek; d++) d: <String>{},
    };

    // Find a teacher who can take [subject] at (d,p) respecting global busy.
    String? findTeacher(String subject, int d, int p) {
      for (final t in teachers) {
        if (t.subjects.contains(subject) && teacherFree(t.id, d, p)) return t.id;
      }
      return null;
    }

    void place(GeneratedPeriod gp) {
      grid[idx(gp.day, gp.period)] = gp;
      if (gp.teacherId != null && gp.teacherId!.isNotEmpty) {
        teacherBusy.add(tKey(gp.teacherId!, gp.day, gp.period));
      }
      if (gp.room != null) roomBusy.add(rKey(gp.room!, gp.day, gp.period));
      usedSubjectToday[gp.day]!.add(gp.subject);
    }

    // --- Rule: period 1 every day belongs to the class teacher. ---
    final ct = cls.classTeacherId == null ? null : teacherById[cls.classTeacherId];
    if (ct == null) {
      warnings.add(
        '${cls.classLabel}: no class teacher set — first period not reserved. '
        'Assign a class teacher so attendance is taken at period 1.',
      );
    } else {
      for (var d = 1; d <= daysPerWeek; d++) {
        if (!teacherFree(ct.id, d, 1)) {
          warnings.add(
            '${cls.classLabel}: class teacher ${ct.name} is already booked at '
            'day $d period 1 — first period left for manual fix.',
          );
          continue;
        }
        // Prefer a required subject the class teacher actually teaches.
        String? subject;
        for (final name in remaining.keys) {
          final spec = specByName[name]!;
          if (remaining[name]! > 0 &&
              ct.subjects.contains(name) &&
              roomFree(spec.requiresRoom, d, 1)) {
            subject = name;
            break;
          }
        }
        if (subject != null) {
          remaining[subject] = remaining[subject]! - 1;
          place(GeneratedPeriod(
            classLabel: cls.classLabel,
            day: d,
            period: 1,
            subject: subject,
            teacherId: ct.id,
            teacherName: ct.name,
            room: specByName[subject]!.requiresRoom,
            isClassTeacherPeriod: true,
          ));
        } else {
          // Homeroom: class teacher present for attendance, no academic subject.
          place(GeneratedPeriod(
            classLabel: cls.classLabel,
            day: d,
            period: 1,
            subject: 'Class Teacher Period',
            teacherId: ct.id,
            teacherName: ct.name,
            isClassTeacherPeriod: true,
          ));
        }
      }
    }

    // --- Fill every remaining slot greedily. ---
    for (var d = 1; d <= daysPerWeek; d++) {
      for (var p = 1; p <= periodsPerDay; p++) {
        if (grid[idx(d, p)] != null) continue;

        // Candidate subjects with demand left, staffable, room-free.
        // Prefer one not already used today (spread), then any.
        String? chosen;
        String? chosenTeacher;
        String? fallback;
        String? fallbackTeacher;
        for (final name in remaining.keys) {
          if (remaining[name]! <= 0) continue;
          final spec = specByName[name]!;
          if (!roomFree(spec.requiresRoom, d, p)) continue;
          final teacher = findTeacher(name, d, p);
          if (teacher == null) continue;
          if (!usedSubjectToday[d]!.contains(name)) {
            chosen = name;
            chosenTeacher = teacher;
            break;
          }
          fallback ??= name;
          fallbackTeacher ??= teacher;
        }
        chosen ??= fallback;
        chosenTeacher ??= fallbackTeacher;

        if (chosen != null && chosenTeacher != null) {
          remaining[chosen] = remaining[chosen]! - 1;
          place(GeneratedPeriod(
            classLabel: cls.classLabel,
            day: d,
            period: p,
            subject: chosen,
            teacherId: chosenTeacher,
            teacherName: teacherById[chosenTeacher]?.name,
            room: specByName[chosen]!.requiresRoom,
          ));
        } else {
          // Nothing placeable — leave a free period.
          place(GeneratedPeriod(
            classLabel: cls.classLabel,
            day: d,
            period: p,
            subject: 'Free',
            isFree: true,
          ));
        }
      }
    }

    // Anything still owed couldn't fit — surface it.
    remaining.forEach((name, count) {
      if (count > 0) {
        warnings.add(
          '${cls.classLabel}: could not place $count period(s) of $name '
          '(not enough free slots or no available teacher).',
        );
      }
    });

    out.addAll(grid.whereType<GeneratedPeriod>());
  }

  return GeneratedTimetable(periods: out, warnings: warnings);
}
