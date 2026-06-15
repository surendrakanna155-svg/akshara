enum AiContentType {
  notice,
  circular,
  parentMessage,
  reportComment,
  meetingSummary,
}

extension AiContentTypeX on AiContentType {
  String get label => switch (this) {
        AiContentType.notice => 'Notice',
        AiContentType.circular => 'Circular',
        AiContentType.parentMessage => 'Parent Message',
        AiContentType.reportComment => 'Report Comment',
        AiContentType.meetingSummary => 'Meeting Summary',
      };
}

class AiContentRequest {
  const AiContentRequest({
    required this.type,
    required this.prompt,
    required this.audience,
    required this.tone,
    this.constraints = '',
  });

  final AiContentType type;
  final String prompt;
  final String audience;
  final String tone;
  final String constraints;
}

class AiGeneratedContent {
  const AiGeneratedContent({
    required this.type,
    required this.content,
    required this.generatedAt,
  });

  final AiContentType type;
  final String content;
  final DateTime generatedAt;
}
