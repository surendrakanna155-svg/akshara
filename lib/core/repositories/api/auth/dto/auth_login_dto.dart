import '../../admissions/dto/api_envelope_dto.dart';

class AuthLoginDto {
  const AuthLoginDto({required this.raw});

  factory AuthLoginDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AuthLoginDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
