/// Standard API error payload from the admissions backend.
class ApiErrorDto {
  const ApiErrorDto({
    required this.code,
    required this.message,
    this.details = const [],
    this.correlationId,
  });

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDto(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Request failed.',
      details: [
        for (final item in json['details'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>) item,
      ],
      correlationId: json['correlationId'] as String?,
    );
  }

  final String code;
  final String message;
  final List<Map<String, dynamic>> details;
  final String? correlationId;

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (details.isNotEmpty) 'details': details,
        if (correlationId != null) 'correlationId': correlationId,
      };
}
