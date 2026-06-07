import '../../../../../features/admissions/admissions_requests.dart';

class ApprovalRequestDto {
  const ApprovalRequestDto({required this.raw});

  factory ApprovalRequestDto.decision(ApprovalDecisionRequest request) {
    return ApprovalRequestDto(raw: {'comment': request.comment});
  }

  factory ApprovalRequestDto.note(ApprovalNoteRequest request) {
    return ApprovalRequestDto(raw: {'content': request.content});
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
