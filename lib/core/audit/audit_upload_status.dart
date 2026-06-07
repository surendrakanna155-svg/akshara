import 'package:flutter/foundation.dart';

import 'audit_event.dart';

/// Lifecycle state for a queued audit upload.
enum UploadStatus {
  pending,
  uploading,
  uploaded,
  failed,
}

/// A single audit event awaiting or completing server upload.
@immutable
class AuditUploadEntry {
  const AuditUploadEntry({
    required this.event,
    this.status = UploadStatus.pending,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  final AuditEvent event;
  final UploadStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;

  factory AuditUploadEntry.fromJson(Map<String, dynamic> json) {
    return AuditUploadEntry(
      event: AuditEvent.fromJson(json['event'] as Map<String, dynamic>),
      status: UploadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => UploadStatus.pending,
      ),
      retryCount: json['retryCount'] as int? ?? 0,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.tryParse(json['lastAttemptAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'event': event.toJson(),
        'status': status.name,
        'retryCount': retryCount,
        if (lastAttemptAt != null)
          'lastAttemptAt': lastAttemptAt!.toIso8601String(),
        if (lastError != null) 'lastError': lastError,
      };

  AuditUploadEntry copyWith({
    AuditEvent? event,
    UploadStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return AuditUploadEntry(
      event: event ?? this.event,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }
}
