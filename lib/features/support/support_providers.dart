import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/incident_context_providers.dart';
import '../../core/repositories/paginated_result.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'domain/support_models.dart';

/// The reporter's own incidents, optionally filtered by [SupportStatus] (null =
/// all). autoDispose so leaving the list frees it; invalidated after a create.
final myReportedIncidentsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<SupportIncident>, SupportStatus?>((ref, status) async {
  final repo = ref.watch(supportRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  return repo.listIncidents(query: query, status: status);
});

/// Full detail (incident + timeline + messages + attachments) for one incident.
final supportIncidentDetailProvider = FutureProvider.autoDispose
    .family<SupportIncidentDetail, String>((ref, incidentId) async {
  final repo = ref.watch(supportRepositoryProvider);
  final query = ref.watch(repositoryQueryProvider);
  return repo.getIncident(query: query, incidentId: incidentId);
});

/// A picked screenshot ready to upload (bytes + filename + content type).
@immutable
class ReportAttachment {
  const ReportAttachment({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

/// The outcome of a SUCCESSFUL report submit.
///
/// Only ever constructed from a record the server returned — a failure throws
/// (see `SupportDeliveryFailure`), it never comes back as a result object with a
/// "false" flag, because a half-truthful success is exactly the bug this whole
/// surface exists to prevent.
@immutable
class SupportReportResult {
  const SupportReportResult({
    required this.incident,
    required this.screenshotAttached,
  });

  /// The server-created incident, carrying the server's own `public_ref`.
  final SupportIncident incident;

  /// False when the user attached a screenshot and only the screenshot failed
  /// to upload. The report itself reached support; the screenshot did not, and
  /// the UI says so instead of quietly dropping it.
  final bool screenshotAttached;
}

/// Write-side actions for the support surface. Kept off the widgets so the
/// context capture + create + upload + cache-invalidation orchestration lives in
/// one place.
class SupportActions {
  SupportActions(this._ref);

  final Ref _ref;

  /// Creates an incident with the auto-collected client context, then uploads an
  /// optional screenshot.
  ///
  /// Returns only when the server created the incident — the returned
  /// `public_ref` is therefore always the server's. Throws
  /// `SupportDeliveryFailure` when nothing reached support.
  Future<SupportReportResult> submitReport({
    required String title,
    required String description,
    ReportAttachment? screenshot,
  }) async {
    final repo = _ref.read(supportRepositoryProvider);
    final query = _ref.read(repositoryQueryProvider);

    // Auto-collect the technical context — the reporter never types any of this.
    final context = await _ref.read(incidentContextServiceProvider).capture();

    final incident = await repo.createIncident(
      query: query,
      input: CreateSupportIncidentInput(
        title: title,
        description: description,
        context: context.toJson(),
      ),
    );

    var screenshotAttached = true;
    if (screenshot != null) {
      // A failed attachment upload must not lose the already-created report —
      // but it is reported back to the caller, not swallowed silently.
      try {
        await repo.uploadAttachment(
          query: query,
          incidentId: incident.id,
          kind: AttachmentKind.screenshot,
          fileName: screenshot.fileName,
          contentType: screenshot.contentType,
          bytes: screenshot.bytes,
        );
      } on Object {
        screenshotAttached = false;
      }
    }

    _ref.invalidate(myReportedIncidentsProvider);
    return SupportReportResult(
      incident: incident,
      screenshotAttached: screenshotAttached,
    );
  }

  /// Posts a school-visible reply and refreshes the detail.
  Future<void> reply({
    required String incidentId,
    required String body,
  }) async {
    final repo = _ref.read(supportRepositoryProvider);
    final query = _ref.read(repositoryQueryProvider);
    await repo.postMessage(query: query, incidentId: incidentId, body: body);
    _ref.invalidate(supportIncidentDetailProvider(incidentId));
    _ref.invalidate(myReportedIncidentsProvider);
  }
}

final supportActionsProvider = Provider<SupportActions>((ref) {
  return SupportActions(ref);
});
