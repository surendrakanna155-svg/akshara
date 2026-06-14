import '../../../../../features/school_completion/school_completion_models.dart';

class ApplyTimetableOptimizationRequestDto {
  const ApplyTimetableOptimizationRequestDto({
    required this.academicYearId,
    required this.recommendationIds,
    required this.applyAll,
  });

  factory ApplyTimetableOptimizationRequestDto.fromDomain({
    required String academicYearId,
    required List<String> recommendationIds,
    required bool applyAll,
  }) {
    return ApplyTimetableOptimizationRequestDto(
      academicYearId: academicYearId,
      recommendationIds: recommendationIds,
      applyAll: applyAll,
    );
  }

  factory ApplyTimetableOptimizationRequestDto.fromRequest(
    ApplyTimetableOptimizationRequest request,
  ) {
    return ApplyTimetableOptimizationRequestDto(
      academicYearId: request.academicYearId,
      recommendationIds: request.recommendationIds,
      applyAll: request.applyAll,
    );
  }

  final String academicYearId;
  final List<String> recommendationIds;
  final bool applyAll;

  Map<String, dynamic> toJson() => {
        'academicYearId': academicYearId,
        'recommendationIds': recommendationIds,
        'applyAll': applyAll,
      };
}
