import '../../admissions/dto/api_envelope_dto.dart';

class SisAcademicAssignmentDto {
  const SisAcademicAssignmentDto({required this.raw});

  factory SisAcademicAssignmentDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisAcademicAssignmentDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
