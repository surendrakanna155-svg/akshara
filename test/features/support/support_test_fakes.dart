import 'package:akshara_erp/core/repositories/interfaces/support_repository.dart';
import 'package:akshara_erp/core/repositories/paginated_result.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/support/domain/support_delivery_failure.dart';
import 'package:akshara_erp/features/support/domain/support_models.dart';

SupportIncident sampleIncident({
  String id = 'i1',
  String title = 'Cannot open marks',
  SupportStatus status = SupportStatus.inProgress,
}) {
  return SupportIncident(
    id: id,
    publicRef: 'SUP-ABCD1234',
    title: title,
    description: 'When I tap Marks nothing happens.',
    category: 'permission_rbac',
    status: status,
    severity: SupportSeverity.sev2,
    createdAt: DateTime(2026, 7, 20, 10),
    updatedAt: DateTime(2026, 7, 20, 10, 5),
    moduleKey: 'sis',
  );
}

SupportIncidentDetail sampleDetail() {
  return SupportIncidentDetail(
    incident: sampleIncident(),
    events: [
      SupportIncidentEvent(eventType: 'created', createdAt: DateTime(2026, 7, 20, 10)),
      SupportIncidentEvent(
        eventType: 'message_posted',
        createdAt: DateTime(2026, 7, 20, 10, 2),
      ),
    ],
    messages: [
      SupportMessage(
        id: 'm1',
        senderKind: SupportSenderKind.support,
        visibility: 'school_visible',
        body: 'looking into it',
        createdAt: DateTime(2026, 7, 20, 10, 2),
      ),
    ],
    attachments: const [],
  );
}

/// An incident shaped like something a SERVER returned: an opaque server id and
/// a server-issued public reference. Tests assert the UI shows exactly these —
/// never a client-invented value.
SupportIncident serverCreatedIncident() => SupportIncident(
      id: 'a1b2c3d4-0000-4000-8000-00000000dead',
      publicRef: 'SUP-SERVER-77',
      title: 'Fee receipt PDF opens blank',
      description: 'Blank PDF after collecting a term fee.',
      category: 'unknown',
      status: SupportStatus.newIncident,
      severity: SupportSeverity.sev3,
      createdAt: DateTime(2026, 7, 28, 9),
      updatedAt: DateTime(2026, 7, 28, 9),
    );

/// In-memory [SupportRepository] for widget tests — no Dio, no network.
///
/// Writes are explicitly scriptable so tests can drive the honest-failure path:
/// [createFailures] attempts throw [createFailure] before one succeeds.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({
    this.incidents = const [],
    this.detail,
    this.created,
    this.createFailures = 0,
    this.createFailure = const SupportDeliveryFailure.notDelivered(),
    this.postMessageFailure,
    this.uploadFailure,
  });

  final List<SupportIncident> incidents;
  final SupportIncidentDetail? detail;

  /// What the "server" returns on a successful create.
  final SupportIncident? created;

  /// How many create attempts fail before one succeeds.
  final int createFailures;
  final SupportDeliveryFailure createFailure;
  final SupportDeliveryFailure? postMessageFailure;
  final SupportDeliveryFailure? uploadFailure;

  int createAttempts = 0;
  int postMessageAttempts = 0;

  @override
  Future<SupportIncident> createIncident({
    required RepositoryQuery query,
    required CreateSupportIncidentInput input,
  }) async {
    createAttempts++;
    if (createAttempts <= createFailures) throw createFailure;
    return created ??
        (incidents.isNotEmpty ? incidents.first : sampleIncident());
  }

  @override
  Future<PaginatedResult<SupportIncident>> listIncidents({
    required RepositoryQuery query,
    SupportStatus? status,
  }) async =>
      PaginatedResult(
        items: incidents,
        page: 1,
        pageSize: 20,
        total: incidents.length,
        hasMore: false,
      );

  @override
  Future<SupportIncidentDetail> getIncident({
    required RepositoryQuery query,
    required String incidentId,
  }) async =>
      detail ?? sampleDetail();

  @override
  Future<SupportMessage> postMessage({
    required RepositoryQuery query,
    required String incidentId,
    required String body,
  }) async {
    postMessageAttempts++;
    final failure = postMessageFailure;
    if (failure != null) throw failure;
    return SupportMessage(
      id: 'new',
      senderKind: SupportSenderKind.reporter,
      visibility: 'school_visible',
      body: body,
      createdAt: DateTime(2026, 7, 20, 11),
    );
  }

  @override
  Future<SupportAttachment> uploadAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required AttachmentKind kind,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    final failure = uploadFailure;
    if (failure != null) throw failure;
    return SupportAttachment(
      id: 'att1',
      kind: kind,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
      createdAt: DateTime(2026, 7, 20, 10, 1),
    );
  }
}
