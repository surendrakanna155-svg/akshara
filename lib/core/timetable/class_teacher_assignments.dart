import '../teaching/teacher_assignment_registry.dart';

/// Who is the class teacher of each section.
///
/// This replaces the hard-coded class-teacher facts in
/// [TeacherAssignmentRegistry] with editable data: the admin can set one class
/// teacher per section, and the timetable generator reads it to reserve period 1
/// (attendance) for that teacher.
///
/// In-memory mock store (singleton), seeded from the existing registry so
/// nothing that already relies on "Priya is class teacher of 8-A" breaks.
final class ClassTeacherAssignmentStore {
  ClassTeacherAssignmentStore._();

  static final ClassTeacherAssignmentStore instance =
      ClassTeacherAssignmentStore._();

  /// classLabel ('8-A') -> teacherId ('HR-EMP-101').
  final Map<String, String> _byClass = {};
  bool _seeded = false;

  void _ensureSeed() {
    if (_seeded) return;
    _seeded = true;
    // Seed from the registry's existing class-teacher facts, plus a class
    // teacher for 8-B so a generated school timetable looks complete.
    _byClass['8-A'] = TeacherAssignmentRegistry.priyaSharmaId; // Priya — Maths
    _byClass['8-B'] = TeacherAssignmentRegistry.mrPatelId; //    Mr. Patel — Science
  }

  /// The class teacher's id for [classLabel], or null if none set.
  String? teacherFor(String classLabel) {
    _ensureSeed();
    return _byClass[classLabel];
  }

  /// All current section -> class-teacher assignments.
  Map<String, String> all() {
    _ensureSeed();
    return Map.unmodifiable(_byClass);
  }

  /// Assign (or reassign) the class teacher of [classLabel].
  void assign({required String classLabel, required String teacherId}) {
    _ensureSeed();
    _byClass[classLabel] = teacherId;
  }

  /// Remove the class teacher of [classLabel].
  void clear(String classLabel) {
    _ensureSeed();
    _byClass.remove(classLabel);
  }

  /// Reset to the seeded state (used by tests).
  void reset() {
    _byClass.clear();
    _seeded = false;
  }
}
