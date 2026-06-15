import '../../../../../features/management/management_requests.dart';

class UpdateManagementSettingsRequestDto {
  const UpdateManagementSettingsRequestDto({required this.raw});

  factory UpdateManagementSettingsRequestDto.fromDomain(
    UpdateManagementSettingsRequest request,
  ) {
    return UpdateManagementSettingsRequestDto(
      raw: {
        if (request.academicYear != null) 'academic_year': request.academicYear,
        if (request.updates.isNotEmpty)
          'updates': [
            for (final update in request.updates)
              {
                'section_id': update.sectionId,
                'item_id': update.itemId,
                'value': update.value,
              },
          ],
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
