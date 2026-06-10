import 'academic_json_codec.dart';

class AcademicClassDto {
  const AcademicClassDto({required this.raw});

  factory AcademicClassDto.fromJson(Map<String, dynamic> json) {
    return AcademicClassDto(raw: json);
  }

  final Map<String, dynamic> raw;

  String get classId =>
      raw['classId'] as String? ?? raw['class_id'] as String? ?? '';
  String get academicYearId =>
      raw['academicYearId'] as String? ??
      raw['academic_year_id'] as String? ??
      '';
  String get className =>
      raw['className'] as String? ?? raw['class_name'] as String? ?? '';
  int get displayOrder => academicJsonInt(
        raw['displayOrder'] ?? raw['display_order'],
      );
  String get status => raw['status'] as String? ?? 'active';
}
