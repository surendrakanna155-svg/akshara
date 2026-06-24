import '../../../../../features/admissions/admissions_requests.dart';
import 'admissions_enum_codec.dart';

class ChangeLeadStageRequestDto {
  const ChangeLeadStageRequestDto({required this.raw});

  factory ChangeLeadStageRequestDto.fromDomain(ChangeLeadStageRequest request) {
    return ChangeLeadStageRequestDto(
      raw: {'stage': AdmissionsEnumCodec.leadStageToApi(request.stage)},
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class FollowUpRequestDto {
  const FollowUpRequestDto({required this.raw});

  factory FollowUpRequestDto.fromDomain(FollowUpRequest request) {
    return FollowUpRequestDto(
      raw: {
        'task': request.task,
        'scheduled_label': request.scheduledLabel,
        'outcome': request.outcome,
        'counselor': request.counselor,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class LeadNoteRequestDto {
  const LeadNoteRequestDto({required this.raw});

  factory LeadNoteRequestDto.fromDomain(LeadNoteRequest request) {
    return LeadNoteRequestDto(
      raw: {
        'content': request.content,
        'activity_type': request.activityType,
        if (request.title.isNotEmpty) 'title': request.title,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
