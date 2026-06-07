import '../../admissions/dto/api_envelope_dto.dart';

class AuthUserDto {
  const AuthUserDto({required this.raw});

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AuthUserDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
