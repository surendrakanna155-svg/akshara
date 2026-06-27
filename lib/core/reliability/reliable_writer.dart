import 'model/mutation_outcome.dart';
import 'model/mutation_request.dart';
import 'reliability_ids.dart';
import 'sync/mutation_gateway.dart';

/// The convenient seam repositories/notifiers use to perform a write through the
/// universal platform pipeline (refinement R4). Every write becomes a
/// [MutationRequest] with a fresh idempotency key and is routed by the
/// [MutationGateway] according to the centralized Operation Policy Registry —
/// callers never write offline/queue/retry code themselves.
class ReliableWriter {
  ReliableWriter(this._gateway);

  final MutationGateway _gateway;

  Future<MutationOutcome> runWrite({
    required String type,
    required String method,
    required String path,
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> scope = const <String, dynamic>{},
    String? entityRef,
    String? idempotencyKey,
  }) {
    final MutationRequest request = MutationRequest(
      type: type,
      method: method,
      path: path,
      idempotencyKey: idempotencyKey ?? newOperationId(),
      body: body,
      scope: scope,
      entityRef: entityRef,
    );
    return _gateway.execute(request);
  }
}
