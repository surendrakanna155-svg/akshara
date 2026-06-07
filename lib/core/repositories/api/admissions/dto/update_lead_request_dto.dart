import '../../../../../features/admissions/admissions_requests.dart';
import 'create_lead_request_dto.dart';

class UpdateLeadRequestDto {
  const UpdateLeadRequestDto({required this.raw});

  factory UpdateLeadRequestDto.fromDomain(UpdateLeadRequest request) {
    return UpdateLeadRequestDto(
      raw: {
        if (request.parentName != null) 'parent_name': request.parentName,
        if (request.studentName != null) 'student_name': request.studentName,
        if (request.classLabel != null) 'class_label': request.classLabel,
        if (request.phone != null) 'phone': request.phone,
        if (request.source != null)
          'source': CreateLeadRequestDto.fromDomain(
            CreateLeadRequest(
              parentName: '',
              studentName: '',
              classLabel: '',
              phone: '',
              source: request.source!,
            ),
          ).raw['source'],
        if (request.campaign != null) 'campaign': request.campaign,
        if (request.email != null) 'email': request.email,
        if (request.address != null) 'address': request.address,
        if (request.notes != null) 'notes': request.notes,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
