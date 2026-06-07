import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/admissions/admissions_requests.dart';

class FinanceHandoffRequestDto {
  const FinanceHandoffRequestDto({required this.raw});

  factory FinanceHandoffRequestDto.send(FinanceHandoffRequest request) {
    return FinanceHandoffRequestDto(
      raw: {
        'handoff_id': request.handoffId,
        'fee_structure_id': request.feeStructureId,
      },
    );
  }

  factory FinanceHandoffRequestDto.updateStatus(
    UpdateHandoffStatusRequest request,
  ) {
    return FinanceHandoffRequestDto(
      raw: {
        'status': _handoffStatusToApi(request.status),
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _handoffStatusToApi(FeeHandoffStatus status) =>
      switch (status) {
        FeeHandoffStatus.pending => 'pending',
        FeeHandoffStatus.sentToFinance => 'sent_to_finance',
        FeeHandoffStatus.completed => 'completed',
        FeeHandoffStatus.failed => 'failed',
      };
}
