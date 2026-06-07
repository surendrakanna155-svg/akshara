import '../../admissions/dto/api_envelope_dto.dart';

class SisStudentProfileDto {
  const SisStudentProfileDto({required this.raw});

  factory SisStudentProfileDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisStudentProfileDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
