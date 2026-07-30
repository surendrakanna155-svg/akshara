import '../../../../../features/support/domain/support_models.dart';
import '../dto/support_dtos.dart';

/// Maps snake_case support DTOs to the snake-free domain models. This is the one
/// place DTO field names ever appear in the domain path (Constitution LAW 9 —
/// no DTO leakage past the mapper).
class SupportMapper {
  const SupportMapper();

  DateTime _date(String? raw) => DateTime.tryParse(raw ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? _dateOrNull(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  SupportIncident toIncident(SupportIncidentDto dto) {
    return SupportIncident(
      id: dto.id,
      publicRef: dto.publicRef,
      title: dto.title,
      description: dto.description,
      category: dto.category,
      status: SupportStatus.fromWire(dto.status),
      severity: SupportSeverity.fromWire(dto.severity),
      createdAt: _date(dto.createdAt),
      updatedAt: _date(dto.updatedAt),
      reporterRole: dto.reporterRole.isEmpty ? null : dto.reporterRole,
      moduleKey: dto.moduleKey,
      screenRoute: dto.screenRoute,
      appVersion: dto.appVersion,
      platform: dto.platform,
      deviceModel: dto.deviceModel,
      osVersion: dto.osVersion,
      resolvedAt: _dateOrNull(dto.resolvedAt),
      resolutionSummary: dto.resolutionSummary,
      firstSeenAt: _dateOrNull(dto.firstSeenAt),
    );
  }

  List<SupportIncident> toIncidents(List<SupportIncidentDto> dtos) =>
      [for (final d in dtos) toIncident(d)];

  SupportIncidentEvent toEvent(SupportEventDto dto) {
    return SupportIncidentEvent(
      eventType: dto.eventType,
      createdAt: _date(dto.createdAt),
      actorUserId: dto.actorUserId,
      fromValue: dto.fromValue,
      toValue: dto.toValue,
    );
  }

  SupportMessage toMessage(SupportMessageDto dto) {
    return SupportMessage(
      id: dto.id,
      senderKind: SupportSenderKind.fromWire(dto.senderKind),
      visibility: dto.visibility,
      body: dto.body,
      createdAt: _date(dto.createdAt),
      senderUserId: dto.senderUserId,
    );
  }

  SupportAttachment toAttachment(SupportAttachmentDto dto) {
    return SupportAttachment(
      id: dto.id,
      kind: AttachmentKind.fromWire(dto.kind),
      fileName: dto.fileName,
      contentType: dto.contentType,
      sizeBytes: dto.sizeBytes,
      createdAt: _date(dto.createdAt),
      downloadUrl: dto.downloadUrl,
    );
  }

  SupportIncidentDetail toDetail(SupportIncidentDetailDto dto) {
    return SupportIncidentDetail(
      incident: toIncident(dto.incident),
      events: [for (final e in dto.events) toEvent(e)],
      messages: [for (final m in dto.messages) toMessage(m)],
      attachments: [for (final a in dto.attachments) toAttachment(a)],
    );
  }

  AttachmentPresign toPresign(SupportPresignDto dto) {
    return AttachmentPresign(
      signedUrl: dto.signedUrl,
      token: dto.token,
      storagePath: dto.storagePath,
    );
  }
}
