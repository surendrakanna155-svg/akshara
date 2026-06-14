import '../../../../../features/admissions/admissions_requests.dart';

class UpdateAdmissionsSettingsRequestDto {
  const UpdateAdmissionsSettingsRequestDto({required this.raw});

  factory UpdateAdmissionsSettingsRequestDto.fromDomain(
    UpdateAdmissionsSettingsRequest request,
  ) {
    return UpdateAdmissionsSettingsRequestDto(
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
