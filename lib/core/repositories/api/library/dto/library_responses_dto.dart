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

/// LIB-1 — `GET /library/overdue` → `{items:[…], count}` inside the envelope.
class LibraryOverdueResponseDto {
  const LibraryOverdueResponseDto({required this.items});

  factory LibraryOverdueResponseDto.fromJson(Map<String, dynamic> json) {
    final data = ApiEnvelopeDto.fromJson(json).requireData();
    final rawItems = data['items'];
    return LibraryOverdueResponseDto(
      items: [
        if (rawItems is List)
          for (final item in rawItems)
            if (item is Map<String, dynamic>) item,
      ],
    );
  }

  final List<Map<String, dynamic>> items;
}

/// LIB-2 — the unwrapped `{imported, failed:[…]}` bulk-import write payload.
class ImportResultRaw {
  const ImportResultRaw({required this.raw});

  final Map<String, dynamic> raw;
}

/// LIB-D1 — `GET/PUT /library/settings` → a flat settings map in the envelope.
class LibrarySettingsDto {
  const LibrarySettingsDto({required this.raw});

  factory LibrarySettingsDto.fromJson(Map<String, dynamic> json) {
    return LibrarySettingsDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}
