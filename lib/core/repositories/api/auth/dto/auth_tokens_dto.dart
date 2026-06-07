import '../../admissions/dto/api_envelope_dto.dart';

class AuthTokensDto {
  const AuthTokensDto({required this.raw});

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AuthTokensDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
