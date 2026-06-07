import 'session_metadata.dart';

/// Enforces maximum session age and idle-timeout rules.
class SessionExpirationPolicy {
  const SessionExpirationPolicy({
    this.maxSessionAge = const Duration(days: 30),
    this.idleTimeout = const Duration(hours: 8),
  });

  final Duration maxSessionAge;
  final Duration idleTimeout;

  /// Returns `true` when the session exceeded [maxSessionAge].
  bool isMaxAgeExceeded(DeviceSessionMetadata metadata, {DateTime? now}) {
    final startedAt = metadata.sessionStartedAt;
    if (startedAt == null) return false;
    final reference = now ?? DateTime.now();
    return reference.difference(startedAt) > maxSessionAge;
  }

  /// Returns `true` when idle time exceeded [idleTimeout].
  bool isIdleTimeoutExceeded(DeviceSessionMetadata metadata, {DateTime? now}) {
    final lastActivity = metadata.lastActivityAt ?? metadata.sessionStartedAt;
    if (lastActivity == null) return false;
    final reference = now ?? DateTime.now();
    return reference.difference(lastActivity) > idleTimeout;
  }

  /// Returns `true` when either max age or idle timeout is exceeded.
  bool isSessionExpired(DeviceSessionMetadata metadata, {DateTime? now}) {
    return isMaxAgeExceeded(metadata, now: now) ||
        isIdleTimeoutExceeded(metadata, now: now);
  }

  /// Builds metadata for a newly established session.
  DeviceSessionMetadata startSession({
    String? deviceId,
    String? sessionId,
    DateTime? at,
  }) {
    final timestamp = at ?? DateTime.now();
    return DeviceSessionMetadata(
      deviceId: deviceId,
      sessionId: sessionId,
      sessionStartedAt: timestamp,
      lastActivityAt: timestamp,
    );
  }
}

const sessionExpirationPolicy = SessionExpirationPolicy();
