import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class AlumniDashboardDto {
  const AlumniDashboardDto({required this.raw});

  factory AlumniDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class AlumniRecordDto {
  const AlumniRecordDto({required this.raw});

  factory AlumniRecordDto.fromJson(Map<String, dynamic> json) {
    return AlumniRecordDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class AlumniRegistryResponseDto {
  const AlumniRegistryResponseDto({
    required this.items,
    this.pagination,
  });

  factory AlumniRegistryResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniRegistryResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          AlumniRecordDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<AlumniRecordDto> items;
  final PaginationDto? pagination;
}

class AlumniDetailDto {
  const AlumniDetailDto({required this.raw});

  factory AlumniDetailDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniDetailDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class AlumniEventDto {
  const AlumniEventDto({required this.raw});

  factory AlumniEventDto.fromJson(Map<String, dynamic> json) {
    return AlumniEventDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class AlumniEventsResponseDto {
  const AlumniEventsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AlumniEventsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniEventsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          AlumniEventDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<AlumniEventDto> items;
  final PaginationDto? pagination;
}

class AlumniDonationDto {
  const AlumniDonationDto({required this.raw});

  factory AlumniDonationDto.fromJson(Map<String, dynamic> json) {
    return AlumniDonationDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class AlumniDonationsResponseDto {
  const AlumniDonationsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AlumniDonationsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniDonationsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          AlumniDonationDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<AlumniDonationDto> items;
  final PaginationDto? pagination;
}

class AlumniCampaignDto {
  const AlumniCampaignDto({required this.raw});

  factory AlumniCampaignDto.fromJson(Map<String, dynamic> json) {
    return AlumniCampaignDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class AlumniCampaignsResponseDto {
  const AlumniCampaignsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AlumniCampaignsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniCampaignsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          AlumniCampaignDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<AlumniCampaignDto> items;
  final PaginationDto? pagination;
}

class MentorshipPairDto {
  const MentorshipPairDto({required this.raw});

  factory MentorshipPairDto.fromJson(Map<String, dynamic> json) {
    return MentorshipPairDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class MentorshipPairsResponseDto {
  const MentorshipPairsResponseDto({
    required this.items,
    this.pagination,
  });

  factory MentorshipPairsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return MentorshipPairsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          MentorshipPairDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<MentorshipPairDto> items;
  final PaginationDto? pagination;
}

class AlumniReportsResponseDto {
  const AlumniReportsResponseDto({required this.raw});

  factory AlumniReportsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniReportsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class AlumniSettingsResponseDto {
  const AlumniSettingsResponseDto({required this.raw});

  factory AlumniSettingsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AlumniSettingsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
