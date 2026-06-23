import '../../../../../features/student_app/student_requests.dart';

class StudentHomeworkSubmitRequestDto {
  const StudentHomeworkSubmitRequestDto({required this.raw});

  factory StudentHomeworkSubmitRequestDto.fromDomain(
    StudentHomeworkSubmitRequest request,
  ) {
    return StudentHomeworkSubmitRequestDto(
      raw: {
        'homework_id': request.homeworkId,
        if (request.attachmentLabel != null)
          'attachment_label': request.attachmentLabel,
        'notes': request.notes,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class StudentHomeworkSubmitResponseDto {
  const StudentHomeworkSubmitResponseDto({required this.raw});

  factory StudentHomeworkSubmitResponseDto.fromJson(Map<String, dynamic> json) {
    return StudentHomeworkSubmitResponseDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
