/// An immutable description of a single write the app wants to perform.
///
/// This is what every repository write is expressed as before it reaches the
/// [MutationGateway]. It is serialisable so it can be durably queued in the
/// outbox and replayed after an app restart.
class MutationRequest {
  const MutationRequest({
    required this.type,
    required this.method,
    required this.path,
    required this.idempotencyKey,
    this.body = const <String, dynamic>{},
    this.scope = const <String, dynamic>{},
    this.entityRef,
  });

  /// Registry key identifying the operation (e.g. `finance.collectFee`).
  /// Drives the [OperationPolicy] lookup.
  final String type;

  /// HTTP verb: `POST`, `PUT`, `PATCH`, `DELETE`.
  final String method;

  /// API path relative to the backend base URL (e.g. `/finance/collections`).
  final String path;

  /// Stable, client-generated id sent as the `Idempotency-Key` header so a
  /// retried write is replayed (never duplicated) by the server.
  final String idempotencyKey;

  /// JSON request body.
  final Map<String, dynamic> body;

  /// Tenant/school/org scope carried as headers/query by the executor.
  final Map<String, dynamic> scope;

  /// Identity of the entity being mutated (e.g. `attendance:{classId}:{date}`).
  /// Used to preserve per-entity ordering and to identify conflicts.
  final String? entityRef;

  MutationRequest copyWith({
    String? type,
    String? method,
    String? path,
    String? idempotencyKey,
    Map<String, dynamic>? body,
    Map<String, dynamic>? scope,
    String? entityRef,
  }) {
    return MutationRequest(
      type: type ?? this.type,
      method: method ?? this.method,
      path: path ?? this.path,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      body: body ?? this.body,
      scope: scope ?? this.scope,
      entityRef: entityRef ?? this.entityRef,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'method': method,
        'path': path,
        'idempotencyKey': idempotencyKey,
        'body': body,
        'scope': scope,
        'entityRef': entityRef,
      };

  factory MutationRequest.fromJson(Map<String, dynamic> json) {
    return MutationRequest(
      type: json['type'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      body: (json['body'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      scope: (json['scope'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      entityRef: json['entityRef'] as String?,
    );
  }
}
