import '../../admissions/dto/api_envelope_dto.dart';

class OnboardingDashboardDto {
  const OnboardingDashboardDto({required this.raw});

  factory OnboardingDashboardDto.fromJson(Map<String, dynamic> json) {
    return OnboardingDashboardDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class OnboardingImportPreviewDto {
  const OnboardingImportPreviewDto({required this.raw});

  factory OnboardingImportPreviewDto.fromJson(Map<String, dynamic> json) {
    return OnboardingImportPreviewDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class OnboardingImportJobDto {
  const OnboardingImportJobDto({required this.raw});

  factory OnboardingImportJobDto.fromJson(Map<String, dynamic> json) {
    return OnboardingImportJobDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class OnboardingInviteDto {
  const OnboardingInviteDto({required this.raw});

  factory OnboardingInviteDto.fromJson(Map<String, dynamic> json) {
    return OnboardingInviteDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class OnboardingInvitesListDto {
  const OnboardingInvitesListDto({required this.items});

  factory OnboardingInvitesListDto.fromJson(Map<String, dynamic> json) {
    final data = ApiEnvelopeDto.fromJson(json).requireData();
    final items = (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return OnboardingInvitesListDto(items: items);
  }

  final List<Map<String, dynamic>> items;
}
