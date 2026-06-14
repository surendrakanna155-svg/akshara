import '../../../../../core/continuity/continuity_models.dart';

class ContinuityPreviewRequestDto {
  const ContinuityPreviewRequestDto({
    required this.studentId,
    required this.fromClass,
    required this.fromSection,
    required this.toClass,
    required this.toSection,
    required this.academicYear,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'fromClass': fromClass,
      'fromSection': fromSection,
      'toClass': toClass,
      'toSection': toSection,
      'academicYear': academicYear,
    };
  }

  final String studentId;
  final String fromClass;
  final String fromSection;
  final String toClass;
  final String toSection;
  final String academicYear;
}

class MessageOwnershipRequestDto {
  const MessageOwnershipRequestDto({
    required this.fromTeacherId,
    required this.toTeacherId,
    required this.studentIds,
  });

  factory MessageOwnershipRequestDto.fromDomain(
    MessageOwnershipContinuityImpact impact,
  ) {
    return MessageOwnershipRequestDto(
      fromTeacherId: impact.fromTeacherId,
      toTeacherId: impact.toTeacherId,
      studentIds: impact.transferredThreadIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromTeacherId': fromTeacherId,
      'toTeacherId': toTeacherId,
      'studentIds': studentIds,
    };
  }

  final String fromTeacherId;
  final String toTeacherId;
  final List<String> studentIds;
}
