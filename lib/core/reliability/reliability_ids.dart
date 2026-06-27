import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Generates a client-side operation id used as the `Idempotency-Key`. Stable
/// per logical write so a retry is replayed (never duplicated) by the server.
String newOperationId() => _uuid.v4();
