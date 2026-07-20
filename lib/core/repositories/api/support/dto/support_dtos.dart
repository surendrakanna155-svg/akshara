// Wire DTOs for the `/support` module. RESPONSE bodies are snake_case; these
// parse them verbatim and the mapper converts to the snake-free domain models.

String? _asString(dynamic v) => v is String ? v : (v?.toString());
int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
bool _asBool(dynamic v) => v is bool ? v : v == 'true';

List<Map<String, dynamic>> _asMapList(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e is Map<String, dynamic>) e,
      ]
    : const [];

/// A `support_incident` row (used by create / list / detail).
class SupportIncidentDto {
  const SupportIncidentDto(this.json);

  final Map<String, dynamic> json;

  factory SupportIncidentDto.fromJson(Map<String, dynamic> json) =>
      SupportIncidentDto(json);

  String get id => _asString(json['id']) ?? '';
  String get publicRef => _asString(json['public_ref']) ?? '';
  String get reporterRole => _asString(json['reporter_role']) ?? '';
  String get title => _asString(json['title']) ?? '';
  String get description => _asString(json['description']) ?? '';
  String get category => _asString(json['category']) ?? 'unknown';
  String get status => _asString(json['status']) ?? 'new';
  String get severity => _asString(json['severity']) ?? 'sev3';
  String? get moduleKey => _asString(json['module_key']);
  String? get screenRoute => _asString(json['screen_route']);
  String? get appVersion => _asString(json['app_version']);
  String? get platform => _asString(json['platform']);
  String? get deviceModel => _asString(json['device_model']);
  String? get osVersion => _asString(json['os_version']);
  String? get resolvedAt => _asString(json['resolved_at']);
  String? get resolutionSummary => _asString(json['resolution_summary']);
  String? get firstSeenAt => _asString(json['first_seen_at']);
  String get createdAt => _asString(json['created_at']) ?? '';
  String get updatedAt => _asString(json['updated_at']) ?? '';
}

/// The paginated list envelope: `{items, total, page, pageSize, hasMore}`.
class SupportIncidentListDto {
  const SupportIncidentListDto({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory SupportIncidentListDto.fromJson(Map<String, dynamic> json) {
    return SupportIncidentListDto(
      items: [
        for (final row in _asMapList(json['items'])) SupportIncidentDto.fromJson(row),
      ],
      total: _asInt(json['total']),
      page: json['page'] == null ? 1 : _asInt(json['page']),
      pageSize: json['pageSize'] == null ? 20 : _asInt(json['pageSize']),
      hasMore: _asBool(json['hasMore']),
    );
  }

  final List<SupportIncidentDto> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
}

class SupportEventDto {
  const SupportEventDto(this.json);

  final Map<String, dynamic> json;

  factory SupportEventDto.fromJson(Map<String, dynamic> json) =>
      SupportEventDto(json);

  String get eventType => _asString(json['event_type']) ?? '';
  String? get actorUserId => _asString(json['actor_user_id']);
  String? get fromValue => _asString(json['from_value']);
  String? get toValue => _asString(json['to_value']);
  String get createdAt => _asString(json['created_at']) ?? '';
}

class SupportMessageDto {
  const SupportMessageDto(this.json);

  final Map<String, dynamic> json;

  factory SupportMessageDto.fromJson(Map<String, dynamic> json) =>
      SupportMessageDto(json);

  String get id => _asString(json['id']) ?? '';
  String? get senderUserId => _asString(json['sender_user_id']);
  String get senderKind => _asString(json['sender_kind']) ?? 'system';
  String get visibility => _asString(json['visibility']) ?? 'school_visible';
  String get body => _asString(json['body']) ?? '';
  String get createdAt => _asString(json['created_at']) ?? '';
}

class SupportAttachmentDto {
  const SupportAttachmentDto(this.json);

  final Map<String, dynamic> json;

  factory SupportAttachmentDto.fromJson(Map<String, dynamic> json) =>
      SupportAttachmentDto(json);

  String get id => _asString(json['id']) ?? '';
  String get kind => _asString(json['kind']) ?? 'screenshot';
  String get fileName => _asString(json['file_name']) ?? '';
  String get contentType => _asString(json['content_type']) ?? '';
  int get sizeBytes => _asInt(json['size_bytes']);
  String? get downloadUrl => _asString(json['download_url']);
  String get createdAt => _asString(json['created_at']) ?? '';
}

/// The `GET /support/incidents/:id` bundle.
class SupportIncidentDetailDto {
  const SupportIncidentDetailDto({
    required this.incident,
    required this.events,
    required this.messages,
    required this.attachments,
  });

  factory SupportIncidentDetailDto.fromJson(Map<String, dynamic> json) {
    final incident = json['incident'];
    return SupportIncidentDetailDto(
      incident: SupportIncidentDto.fromJson(
        incident is Map<String, dynamic> ? incident : const {},
      ),
      events: [
        for (final e in _asMapList(json['events'])) SupportEventDto.fromJson(e),
      ],
      messages: [
        for (final m in _asMapList(json['messages'])) SupportMessageDto.fromJson(m),
      ],
      attachments: [
        for (final a in _asMapList(json['attachments']))
          SupportAttachmentDto.fromJson(a),
      ],
    );
  }

  final SupportIncidentDto incident;
  final List<SupportEventDto> events;
  final List<SupportMessageDto> messages;
  final List<SupportAttachmentDto> attachments;
}

class SupportPresignDto {
  const SupportPresignDto({
    required this.signedUrl,
    required this.token,
    required this.storagePath,
  });

  factory SupportPresignDto.fromJson(Map<String, dynamic> json) {
    return SupportPresignDto(
      signedUrl: _asString(json['signed_url']) ?? '',
      token: _asString(json['token']) ?? '',
      storagePath: _asString(json['storage_path']) ?? '',
    );
  }

  final String signedUrl;
  final String token;
  final String storagePath;
}
