import '../../../features/support/domain/support_models.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for ASIP Phase-1 platform-support data access (mock or API).
///
/// Reporter-scoped: any authenticated school user may create + view + converse
/// on their own incidents. The server enforces reporter-owns / support-view
/// RBAC on top of tenant RLS.
abstract class SupportRepository {
  /// `POST /support/incidents` — creates an incident with the auto-collected
  /// client-context block. Returns the created incident (incl. `public_ref`).
  Future<SupportIncident> createIncident({
    required RepositoryQuery query,
    required CreateSupportIncidentInput input,
  });

  /// `GET /support/incidents` — the reporter's own incidents, paginated.
  Future<PaginatedResult<SupportIncident>> listIncidents({
    required RepositoryQuery query,
    SupportStatus? status,
  });

  /// `GET /support/incidents/:id` — incident + timeline + messages + attachments.
  Future<SupportIncidentDetail> getIncident({
    required RepositoryQuery query,
    required String incidentId,
  });

  /// `POST /support/incidents/:id/messages` — posts a school-visible reply.
  Future<SupportMessage> postMessage({
    required RepositoryQuery query,
    required String incidentId,
    required String body,
  });

  /// Full attachment upload: presign → HTTP PUT the bytes → confirm. Returns the
  /// confirmed attachment row.
  Future<SupportAttachment> uploadAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required AttachmentKind kind,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  });
}
