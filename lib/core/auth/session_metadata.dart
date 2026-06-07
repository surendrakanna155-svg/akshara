import 'package:flutter/foundation.dart';

/// Client-side session metadata for expiration and device tracking.
@immutable
class DeviceSessionMetadata {
  const DeviceSessionMetadata({
    this.deviceId,
    this.sessionId,
    this.sessionStartedAt,
    this.lastActivityAt,
  });

  final String? deviceId;
  final String? sessionId;
  final DateTime? sessionStartedAt;
  final DateTime? lastActivityAt;

  DeviceSessionMetadata touch({DateTime? at}) {
    return copyWith(lastActivityAt: at ?? DateTime.now());
  }

  DeviceSessionMetadata copyWith({
    String? deviceId,
    String? sessionId,
    DateTime? sessionStartedAt,
    DateTime? lastActivityAt,
  }) {
    return DeviceSessionMetadata(
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  factory DeviceSessionMetadata.fromJson(Map<String, dynamic> json) {
    return DeviceSessionMetadata(
      deviceId: json['deviceId'] as String?,
      sessionId: json['sessionId'] as String?,
      sessionStartedAt: DateTime.tryParse(
        json['sessionStartedAt'] as String? ?? '',
      ),
      lastActivityAt: DateTime.tryParse(
        json['lastActivityAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        if (deviceId != null) 'deviceId': deviceId,
        if (sessionId != null) 'sessionId': sessionId,
        if (sessionStartedAt != null)
          'sessionStartedAt': sessionStartedAt!.toIso8601String(),
        if (lastActivityAt != null)
          'lastActivityAt': lastActivityAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceSessionMetadata &&
          deviceId == other.deviceId &&
          sessionId == other.sessionId &&
          sessionStartedAt == other.sessionStartedAt &&
          lastActivityAt == other.lastActivityAt;

  @override
  int get hashCode =>
      Object.hash(deviceId, sessionId, sessionStartedAt, lastActivityAt);
}
