import '../../../../../features/parent/parent_requests.dart';

class ParentMessageSendRequestDto {
  const ParentMessageSendRequestDto({
    required this.recipient,
    required this.subject,
    required this.body,
    this.threadId,
  });

  factory ParentMessageSendRequestDto.fromDomain(ParentMessageSendRequest request) {
    return ParentMessageSendRequestDto(
      recipient: request.recipient,
      subject: request.subject,
      body: request.body,
      threadId: request.threadId,
    );
  }

  final String recipient;
  final String subject;
  final String body;
  final String? threadId;

  Map<String, dynamic> toJson() {
    return {
      'recipient': recipient,
      'subject': subject,
      'body': body,
      if (threadId != null) 'threadId': threadId,
    };
  }
}
