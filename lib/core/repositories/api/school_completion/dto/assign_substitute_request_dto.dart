import '../../../../../features/school_completion/school_completion_models.dart';

class AssignSubstituteRequestDto {
  const AssignSubstituteRequestDto({
    required this.slotId,
    required this.substituteTeacherId,
    required this.notifySubstituteTeacher,
    required this.notifyClassIncharge,
    required this.notifyStudents,
  });

  factory AssignSubstituteRequestDto.fromDomain(AssignSubstituteRequest request) {
    return AssignSubstituteRequestDto(
      slotId: request.slotId,
      substituteTeacherId: request.substituteTeacherId,
      notifySubstituteTeacher: request.notifySubstituteTeacher,
      notifyClassIncharge: request.notifyClassIncharge,
      notifyStudents: request.notifyStudents,
    );
  }

  final String slotId;
  final String substituteTeacherId;
  final bool notifySubstituteTeacher;
  final bool notifyClassIncharge;
  final bool notifyStudents;

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'substituteTeacherId': substituteTeacherId,
        'notifySubstituteTeacher': notifySubstituteTeacher,
        'notifyClassIncharge': notifyClassIncharge,
        'notifyStudents': notifyStudents,
      };
}
