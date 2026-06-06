import 'package:flutter/foundation.dart';

enum MessageMailbox { inbox, sent, compose }

extension MessageMailboxX on MessageMailbox {
  String get label => switch (this) {
        MessageMailbox.inbox => 'Inbox',
        MessageMailbox.sent => 'Sent',
        MessageMailbox.compose => 'Compose',
      };
}

@immutable
class MessageThread {
  const MessageThread({
    required this.id,
    required this.parentName,
    required this.studentName,
    required this.preview,
    required this.timeLabel,
    required this.unreadCount,
    required this.messages,
  });

  final String id;
  final String parentName;
  final String studentName;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final List<MessageItem> messages;
}

@immutable
class MessageItem {
  const MessageItem({
    required this.id,
    required this.body,
    required this.senderLabel,
    required this.timeLabel,
    required this.isTeacher,
  });

  final String id;
  final String body;
  final String senderLabel;
  final String timeLabel;
  final bool isTeacher;
}

@immutable
class ComposeDraft {
  const ComposeDraft({
    this.recipient = '',
    this.subject = '',
    this.body = '',
  });

  final String recipient;
  final String subject;
  final String body;

  bool get isValid =>
      recipient.trim().isNotEmpty && body.trim().length >= 4;

  ComposeDraft copyWith({String? recipient, String? subject, String? body}) {
    return ComposeDraft(
      recipient: recipient ?? this.recipient,
      subject: subject ?? this.subject,
      body: body ?? this.body,
    );
  }
}
