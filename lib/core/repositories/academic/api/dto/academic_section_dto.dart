import 'academic_json_codec.dart';

class AcademicSectionDto {
  const AcademicSectionDto({required this.raw});

  factory AcademicSectionDto.fromJson(Map<String, dynamic> json) {
    return AcademicSectionDto(raw: json);
  }

  final Map<String, dynamic> raw;

  String get sectionId =>
      raw['sectionId'] as String? ?? raw['section_id'] as String? ?? '';
  String get classId =>
      raw['classId'] as String? ?? raw['class_id'] as String? ?? '';
  String get className =>
      raw['className'] as String? ?? raw['class_name'] as String? ?? '';
  String get sectionName =>
      raw['sectionName'] as String? ?? raw['section_name'] as String? ?? '';
  int get capacity => academicJsonInt(raw['capacity']);
  int get strength => academicJsonInt(raw['strength']);
  String get status => raw['status'] as String? ?? 'active';
}
