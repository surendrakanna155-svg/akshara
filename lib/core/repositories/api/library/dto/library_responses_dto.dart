import '../../admissions/dto/api_envelope_dto.dart';

class LibraryDashboardDto {
  const LibraryDashboardDto({required this.raw});

  factory LibraryDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class LibraryBookDto {
  const LibraryBookDto({required this.raw});

  factory LibraryBookDto.fromJson(Map<String, dynamic> json) {
    return LibraryBookDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class LibraryCatalogResponseDto {
  const LibraryCatalogResponseDto({required this.items});

  factory LibraryCatalogResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryCatalogResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          LibraryBookDto.fromJson(item),
      ],
    );
  }

  final List<LibraryBookDto> items;
}

class LibraryIssueRecordDto {
  const LibraryIssueRecordDto({required this.raw});

  factory LibraryIssueRecordDto.fromJson(Map<String, dynamic> json) {
    return LibraryIssueRecordDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class LibraryIssuesResponseDto {
  const LibraryIssuesResponseDto({required this.items});

  factory LibraryIssuesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryIssuesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          LibraryIssueRecordDto.fromJson(item),
      ],
    );
  }

  final List<LibraryIssueRecordDto> items;
}

class LibraryReturnRecordDto {
  const LibraryReturnRecordDto({required this.raw});

  factory LibraryReturnRecordDto.fromJson(Map<String, dynamic> json) {
    return LibraryReturnRecordDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class LibraryReturnsResponseDto {
  const LibraryReturnsResponseDto({required this.items});

  factory LibraryReturnsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryReturnsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          LibraryReturnRecordDto.fromJson(item),
      ],
    );
  }

  final List<LibraryReturnRecordDto> items;
}

class LibraryMemberDto {
  const LibraryMemberDto({required this.raw});

  factory LibraryMemberDto.fromJson(Map<String, dynamic> json) {
    return LibraryMemberDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class LibraryMembersResponseDto {
  const LibraryMembersResponseDto({required this.items});

  factory LibraryMembersResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryMembersResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          LibraryMemberDto.fromJson(item),
      ],
    );
  }

  final List<LibraryMemberDto> items;
}

class LibraryFinesResponseDto {
  const LibraryFinesResponseDto({required this.raw});

  factory LibraryFinesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryFinesResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class LibraryDigitalResourcesResponseDto {
  const LibraryDigitalResourcesResponseDto({required this.raw});

  factory LibraryDigitalResourcesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryDigitalResourcesResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class LibraryReportsResponseDto {
  const LibraryReportsResponseDto({required this.raw});

  factory LibraryReportsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LibraryReportsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
