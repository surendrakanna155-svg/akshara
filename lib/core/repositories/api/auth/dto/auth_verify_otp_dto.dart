import '../../admissions/dto/api_envelope_dto.dart';

class AuthVerifyOtpDto {
  const AuthVerifyOtpDto({required this.raw});

  factory AuthVerifyOtpDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AuthVerifyOtpDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
