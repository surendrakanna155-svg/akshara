import 'package:flutter/foundation.dart';

/// ASIP Phase 1 — client domain models for the school-facing "Report an issue"
/// flow. These are the mapped, snake-free domain shapes consumed by the UI; the
/// wire DTOs (snake_case) live under `core/repositories/api/support/`.

/// Incident lifecycle status. Wire values are snake_case (`in_progress`).
enum SupportStatus {
  newIncident('new', 'New'),
  triaging('triaging', 'Triaging'),
  inProgress('in_progress', 'In progress'),
  awaitingCustomer('awaiting_customer', 'Awaiting your reply'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const SupportStatus(this.wire, this.label);

  /// Wire value sent to / received from the API.
  final String wire;

  /// Human-readable label for chips + headers.
  final String label;

  /// True while the incident is still being worked (not resolved/closed).
  bool get isOpen => this != SupportStatus.resolved && this != SupportStatus.closed;

  static SupportStatus fromWire(String? value) {
    for (final s in SupportStatus.values) {
      if (s.wire == value) return s;
    }
    return SupportStatus.newIncident;
  }
}

/// Incident severity (support-assigned; reporter sees it read-only).
enum SupportSeverity {
  sev1('sev1', 'Critical'),
  sev2('sev2', 'High'),
  sev3('sev3', 'Medium'),
  sev4('sev4', 'Low');

  const SupportSeverity(this.wire, this.label);

  final String wire;
  final String label;

  static SupportSeverity fromWire(String? value) {
    for (final s in SupportSeverity.values) {
      if (s.wire == value) return s;
    }
    return SupportSeverity.sev3;
  }
}

/// Attachment kind. Screen recording is a Phase-1 deferred affordance (see
/// `report_issue_screen.dart`); the wire contract already supports it.
enum AttachmentKind {
  screenshot('screenshot'),
  screenRecording('screen_recording'),
  logExport('log_export');

  const AttachmentKind(this.wire);

  final String wire;

  static AttachmentKind fromWire(String? value) {
    for (final k in AttachmentKind.values) {
      if (k.wire == value) return k;
    }
    return AttachmentKind.screenshot;
  }
}

/// Who authored a message.
enum SupportSenderKind {
  reporter('reporter'),
  support('support'),
  system('system');

  const SupportSenderKind(this.wire);

  final String wire;

  static SupportSenderKind fromWire(String? value) {
    for (final k in SupportSenderKind.values) {
      if (k.wire == value) return k;
    }
    return SupportSenderKind.system;
  }
}

/// Formats a soft category slug (`login_auth`) into a readable label.
String formatSupportCategory(String? category) {
  if (category == null || category.isEmpty) return 'Unknown';
  return category
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// A reported incident (list row + detail header).
@immutable
class SupportIncident {
  const SupportIncident({
    required this.id,
    required this.publicRef,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.severity,
    required this.createdAt,
    required this.updatedAt,
    this.reporterRole,
    this.moduleKey,
    this.screenRoute,
    this.appVersion,
    this.platform,
    this.deviceModel,
    this.osVersion,
    this.resolvedAt,
    this.resolutionSummary,
    this.firstSeenAt,
  });

  final String id;
  final String publicRef;
  final String title;
  final String description;
  final String category;
  final SupportStatus status;
  final SupportSeverity severity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterRole;
  final String? moduleKey;
  final String? screenRoute;
  final String? appVersion;
  final String? platform;
  final String? deviceModel;
  final String? osVersion;
  final DateTime? resolvedAt;
  final String? resolutionSummary;
  final DateTime? firstSeenAt;
}

/// A single timeline event (created / status_changed / message_posted / …).
@immutable
class SupportIncidentEvent {
  const SupportIncidentEvent({
    required this.eventType,
    required this.createdAt,
    this.actorUserId,
    this.fromValue,
    this.toValue,
  });

  final String eventType;
  final DateTime createdAt;
  final String? actorUserId;
  final String? fromValue;
  final String? toValue;
}

/// A conversation message.
@immutable
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderKind,
    required this.visibility,
    required this.body,
    required this.createdAt,
    this.senderUserId,
  });

  final String id;
  final SupportSenderKind senderKind;
  final String visibility;
  final String body;
  final DateTime createdAt;
  final String? senderUserId;

  bool get isFromReporter => senderKind == SupportSenderKind.reporter;
  bool get isInternalNote => visibility == 'internal_note';
}

/// An uploaded attachment (screenshot / recording / log).
@immutable
class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    this.downloadUrl,
  });

  final String id;
  final AttachmentKind kind;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;
  final String? downloadUrl;

  bool get isImage => contentType.startsWith('image/');
}

/// Full incident detail bundle returned by `GET /support/incidents/:id`.
/// `evidence`/`analysis` are support-only (null/empty for a reporter) and are
/// therefore not surfaced in the Phase-1 reporter UI.
@immutable
class SupportIncidentDetail {
  const SupportIncidentDetail({
    required this.incident,
    required this.events,
    required this.messages,
    required this.attachments,
  });

  final SupportIncident incident;
  final List<SupportIncidentEvent> events;
  final List<SupportMessage> messages;
  final List<SupportAttachment> attachments;

  /// School-visible messages only (reporters never see internal notes; this
  /// also defends in depth should a support caller's payload ever include them).
  List<SupportMessage> get visibleMessages =>
      messages.where((m) => !m.isInternalNote).toList(growable: false);
}

/// Presigned upload target returned by the presign endpoint.
@immutable
class AttachmentPresign {
  const AttachmentPresign({
    required this.signedUrl,
    required this.token,
    required this.storagePath,
  });

  final String signedUrl;
  final String token;
  final String storagePath;
}

/// Input to create an incident. [context] is the auto-collected client-context
/// block (camelCase, from `IncidentContext.toJson()`); the reporter never fills
/// it in.
@immutable
class CreateSupportIncidentInput {
  const CreateSupportIncidentInput({
    required this.title,
    required this.description,
    this.context,
  });

  final String title;
  final String description;
  final Map<String, dynamic>? context;
}
