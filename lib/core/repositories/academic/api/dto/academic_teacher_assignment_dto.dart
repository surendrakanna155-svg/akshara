import 'academic_json_codec.dart';

class AcademicTeacherAssignmentDto {
  const AcademicTeacherAssignmentDto({required this.raw});

  factory AcademicTeacherAssignmentDto.fromJson(Map<String, dynamic> json) {
    return AcademicTeacherAssignmentDto(raw: json);
  }

  final Map<String, dynamic> raw;

  String get assignmentId =>
      raw['assignmentId'] as String? ?? raw['assignment_id'] as String? ?? '';
  String get teacherId =>
      raw['teacherId'] as String? ?? raw['teacher_id'] as String? ?? '';
  String? get teacherName =>
      raw['teacherName'] as String? ?? raw['teacher_name'] as String?;
  String get classId =>
      raw['classId'] as String? ?? raw['class_id'] as String? ?? '';
  String get className =>
      raw['className'] as String? ?? raw['class_name'] as String? ?? '';
  String get sectionId =>
      raw['sectionId'] as String? ?? raw['section_id'] as String? ?? '';
  String get sectionName =>
      raw['sectionName'] as String? ?? raw['section_name'] as String? ?? '';
  String get role => raw['role'] as String? ?? '';
  bool get isPrimary => academicJsonBool(
        raw['isPrimary'] ?? raw['is_primary'],
      );
}
