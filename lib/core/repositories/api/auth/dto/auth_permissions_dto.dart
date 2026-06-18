import '../../admissions/dto/api_envelope_dto.dart';

class AuthPermissionsDto {
  const AuthPermissionsDto({
    required this.items,
    this.permissionsVersion,
    this.etag,
    this.syncedAt,
  });

  factory AuthPermissionsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    final data = envelope.requireData();
    final permissionsField = data['permissions'] ?? data['items'];
    final versionRaw = data['permissionsVersion'] ?? data['version'];
    final syncedRaw = data['syncedAt'] as String?;
    final items = permissionsField is List
        ? [
            for (final item in permissionsField)
              if (item is Map<String, dynamic>) item,
          ]
        : [
            for (final item in envelope.requireListItems()) item,
          ];
    return AuthPermissionsDto(
      items: items,
      permissionsVersion: versionRaw is int
          ? versionRaw
          : int.tryParse(versionRaw?.toString() ?? ''),
      etag: data['etag'] as String?,
      syncedAt: syncedRaw != null ? DateTime.tryParse(syncedRaw) : null,
    );
  }

  final List<Map<String, dynamic>> items;
  final int? permissionsVersion;
  final String? etag;
  final DateTime? syncedAt;
}
