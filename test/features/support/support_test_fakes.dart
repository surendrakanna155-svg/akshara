import 'package:akshara_erp/core/repositories/interfaces/support_repository.dart';
import 'package:akshara_erp/core/repositories/paginated_result.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
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

/// In-memory [SupportRepository] for widget tests — no Dio, no network.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({this.incidents = const [], this.detail});

  final List<SupportIncident> incidents;
  final SupportIncidentDetail? detail;

  @override
  Future<SupportIncident> createIncident({
    required RepositoryQuery query,
    required CreateSupportIncidentInput input,
  }) async =>
      incidents.isNotEmpty ? incidents.first : sampleIncident();

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
  }) async =>
      SupportMessage(
        id: 'new',
        senderKind: SupportSenderKind.reporter,
        visibility: 'school_visible',
        body: body,
        createdAt: DateTime(2026, 7, 20, 11),
      );

  @override
  Future<SupportAttachment> uploadAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required AttachmentKind kind,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async =>
      SupportAttachment(
        id: 'att1',
        kind: kind,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: bytes.length,
        createdAt: DateTime(2026, 7, 20, 10, 1),
      );
}
