import '../../../../../features/admissions/admissions_requests.dart';
import 'admissions_enum_codec.dart';

/// ADM-3: bulk assign/stage payload for `POST /admissions/leads/bulk`.
///
/// Serializes to `{leadIds, action, counselor?|stage?}` with snake_case-safe
/// keys the backend accepts (it reads both `leadIds`/`lead_ids`).
class BulkLeadActionRequestDto {
  const BulkLeadActionRequestDto({required this.raw});

  factory BulkLeadActionRequestDto.fromDomain(BulkLeadActionRequest request) {
    final raw = <String, dynamic>{
      'leadIds': request.leadIds,
      'action': request.action == BulkLeadAction.assign ? 'assign' : 'stage',
    };
    if (request.action == BulkLeadAction.assign) {
      raw['counselor'] = request.counselor ?? '';
    } else {
      raw['stage'] = request.stage == null
          ? ''
          : AdmissionsEnumCodec.leadStageToApi(request.stage!);
    }
    return BulkLeadActionRequestDto(raw: raw);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

/// ADM-D1: `PATCH /admissions/leads/{id}/lost` — `{reason}`.
class MarkLeadLostRequestDto {
  const MarkLeadLostRequestDto({required this.raw});

  factory MarkLeadLostRequestDto.fromDomain(MarkLeadLostRequest request) {
    return MarkLeadLostRequestDto(raw: {'reason': request.reason.apiValue});
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

/// ADM-4: `POST /admissions/leads/{id}/followups/{fid}/complete` — `{outcome?}`.
class CompleteFollowUpRequestDto {
  const CompleteFollowUpRequestDto({required this.raw});

  factory CompleteFollowUpRequestDto.fromDomain(
    CompleteFollowUpRequest request,
  ) {
    return CompleteFollowUpRequestDto(
      raw: {if (request.outcome.isNotEmpty) 'outcome': request.outcome},
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

/// ADM-4: `POST /admissions/leads/{id}/followups/{fid}/reschedule` —
/// `{scheduledLabel}` (backend reads `scheduled_label`).
class RescheduleFollowUpRequestDto {
  const RescheduleFollowUpRequestDto({required this.raw});

  factory RescheduleFollowUpRequestDto.fromDomain(
    RescheduleFollowUpRequest request,
  ) {
    return RescheduleFollowUpRequestDto(
      raw: {'scheduled_label': request.scheduledLabel},
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
