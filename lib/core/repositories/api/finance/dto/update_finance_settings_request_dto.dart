import '../../../../../features/finance/finance_requests.dart';

class UpdateFinanceSettingsRequestDto {
  const UpdateFinanceSettingsRequestDto({required this.raw});

  factory UpdateFinanceSettingsRequestDto.fromDomain(
    UpdateFinanceSettingsRequest request,
  ) {
    return UpdateFinanceSettingsRequestDto(
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
