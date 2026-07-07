import '../../core/errors/api_failure.dart';

/// C-ISS-4 / Guide §9 — the app's single catalog of user-facing STATE copy, so
/// screens never invent one-off strings or leak raw enums / error codes. Covers
/// the recoverable-error, permission-denied, session-expired, offline and empty
/// states that the shared status widgets render.
abstract final class AksharaCopy {
  // Generic recoverable error.
  static const String errorTitle = 'Something went wrong';
  static const String errorRetry = 'Try again';

  // Permission denied — an access boundary, NOT a system error.
  static const String permissionTitle = 'You don’t have access';
  static const String permissionMessage =
      'You don’t have permission to view this. Ask an administrator if you '
      'need access.';

  // Session expired (unauthorized).
  static const String sessionExpiredTitle = 'Session expired';
  static const String sessionExpiredMessage =
      'Please sign in again to continue.';

  // Offline / unreachable.
  static const String offlineTitle = 'You’re offline';

  // Generic empty collection.
  static const String emptyTitle = 'Nothing here yet';
}

/// The distinct presentation a failure resolves to. Splitting `permission` (and
/// `sessionExpired`) out of the generic error bucket is the "permission as its
/// own state" rule: an access boundary is not a glitch — it must not read like a
/// crash, and must not offer a pointless "Try again".
enum AksharaFailureKind { error, permission, sessionExpired, offline }

extension AksharaFailurePresentation on ApiFailureType {
  AksharaFailureKind get kind => switch (this) {
        ApiFailureType.forbidden => AksharaFailureKind.permission,
        ApiFailureType.unauthorized => AksharaFailureKind.sessionExpired,
        ApiFailureType.network ||
        ApiFailureType.notConnected ||
        ApiFailureType.timeout =>
          AksharaFailureKind.offline,
        ApiFailureType.server || ApiFailureType.unknown =>
          AksharaFailureKind.error,
      };

  /// Canonical title for this failure's state.
  String get stateTitle => switch (kind) {
        AksharaFailureKind.permission => AksharaCopy.permissionTitle,
        AksharaFailureKind.sessionExpired => AksharaCopy.sessionExpiredTitle,
        AksharaFailureKind.offline => AksharaCopy.offlineTitle,
        AksharaFailureKind.error => AksharaCopy.errorTitle,
      };
}
