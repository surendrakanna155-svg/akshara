import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/admissions/admissions_requests.dart';

class CreateLeadRequestDto {
  const CreateLeadRequestDto({required this.raw});

  factory CreateLeadRequestDto.fromDomain(CreateLeadRequest request) {
    return CreateLeadRequestDto(
      raw: {
        'parent_name': request.parentName,
        'student_name': request.studentName,
        'class_label': request.classLabel,
        'phone': request.phone,
        'source': _leadSourceToApi(request.source),
        'campaign': request.campaign,
        'counselor': request.counselor,
        'email': request.email,
        'address': request.address,
        'notes': request.notes,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _leadSourceToApi(LeadSource source) => switch (source) {
        LeadSource.website => 'website',
        LeadSource.walkIn => 'walk_in',
        LeadSource.referral => 'referral',
        LeadSource.whatsapp => 'whatsapp',
        LeadSource.facebook => 'facebook',
        LeadSource.googleAds => 'google_ads',
      };
}
