import '../../admissions/dto/api_envelope_dto.dart';

class AuthPermissionsDto {
  const AuthPermissionsDto({required this.items});

  factory AuthPermissionsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    final data = envelope.requireData();
    final permissionsField = data['permissions'] ?? data['items'];
    if (permissionsField is List) {
      return AuthPermissionsDto(
        items: [
          for (final item in permissionsField)
            if (item is Map<String, dynamic>) item,
        ],
      );
    }
    return AuthPermissionsDto(
      items: [
        for (final item in envelope.requireListItems()) item,
      ],
    );
  }

  final List<Map<String, dynamic>> items;
}
