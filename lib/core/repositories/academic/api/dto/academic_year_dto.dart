import '../../academic_year_label.dart';
import 'academic_json_codec.dart';

class AcademicYearDto {
  const AcademicYearDto({required this.raw});

  factory AcademicYearDto.fromJson(Map<String, dynamic> json) {
    return AcademicYearDto(raw: json);
  }

  final Map<String, dynamic> raw;

  String get yearId => raw['yearId'] as String? ?? raw['year_id'] as String? ?? '';
  String get yearLabel => normalizeAcademicYearLabel(
        raw['yearLabel'] as String? ?? raw['year_label'] as String? ?? '',
      );
  String get startDate =>
      raw['startDate'] as String? ?? raw['start_date'] as String? ?? '';
  String get endDate =>
      raw['endDate'] as String? ?? raw['end_date'] as String? ?? '';
  bool get isCurrent => academicJsonBool(
        raw['isCurrent'] ?? raw['is_current'],
      );
  String get status => raw['status'] as String? ?? 'active';
}
