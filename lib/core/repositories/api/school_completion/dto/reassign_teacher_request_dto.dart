import '../../../../../features/school_completion/school_completion_models.dart';

class ReassignTeacherRequestDto {
  const ReassignTeacherRequestDto({
    required this.academicYearId,
    required this.sourceTeacherId,
    required this.targetTeacherId,
    required this.slotIds,
    required this.notifySourceTeacher,
    required this.notifyTargetTeacher,
    required this.notifyStudents,
  });

  factory ReassignTeacherRequestDto.fromDomain(ReassignTeacherRequest request) {
    return ReassignTeacherRequestDto(
      academicYearId: request.academicYearId,
      sourceTeacherId: request.sourceTeacherId,
      targetTeacherId: request.targetTeacherId,
      slotIds: request.slotIds,
      notifySourceTeacher: request.notifySourceTeacher,
      notifyTargetTeacher: request.notifyTargetTeacher,
      notifyStudents: request.notifyStudents,
    );
  }

  final String academicYearId;
  final String sourceTeacherId;
  final String targetTeacherId;
  final List<String> slotIds;
  final bool notifySourceTeacher;
  final bool notifyTargetTeacher;
  final bool notifyStudents;

  Map<String, dynamic> toJson() => {
        'academicYearId': academicYearId,
        'sourceTeacherId': sourceTeacherId,
        'targetTeacherId': targetTeacherId,
        'slotIds': slotIds,
        'notifySourceTeacher': notifySourceTeacher,
        'notifyTargetTeacher': notifyTargetTeacher,
        'notifyStudents': notifyStudents,
      };
}
