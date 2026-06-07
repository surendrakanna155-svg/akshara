import 'package:flutter/foundation.dart';

/// OAuth/JWT token pair persisted for API authentication.
@immutable
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.sessionId,
    this.refreshTokenId,
    this.tokenFamilyId,
    this.deviceId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? sessionId;
  final String? refreshTokenId;
  final String? tokenFamilyId;
  final String? deviceId;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isExpiringSoon {
    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(minutes: 5)),
    );
  }

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sessionId: json['sessionId'] as String?,
      refreshTokenId: json['refreshTokenId'] as String?,
      tokenFamilyId: json['tokenFamilyId'] as String?,
      deviceId: json['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        if (sessionId != null) 'sessionId': sessionId,
        if (refreshTokenId != null) 'refreshTokenId': refreshTokenId,
        if (tokenFamilyId != null) 'tokenFamilyId': tokenFamilyId,
        if (deviceId != null) 'deviceId': deviceId,
      };

  bool get isValid =>
      accessToken.isNotEmpty && refreshToken.isNotEmpty && !isExpired;

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? sessionId,
    String? refreshTokenId,
    String? tokenFamilyId,
    String? deviceId,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      sessionId: sessionId ?? this.sessionId,
      refreshTokenId: refreshTokenId ?? this.refreshTokenId,
      tokenFamilyId: tokenFamilyId ?? this.tokenFamilyId,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Demo tokens for development without a backend.
  factory AuthTokens.demo({Duration ttl = const Duration(hours: 1)}) {
    final expires = DateTime.now().add(ttl);
    return AuthTokens(
      accessToken: 'demo_access_${expires.millisecondsSinceEpoch}',
      refreshToken: 'demo_refresh_${expires.millisecondsSinceEpoch}',
      expiresAt: expires,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokens &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresAt == other.expiresAt &&
          sessionId == other.sessionId &&
          refreshTokenId == other.refreshTokenId &&
          tokenFamilyId == other.tokenFamilyId &&
          deviceId == other.deviceId;

  @override
  int get hashCode => Object.hash(
        accessToken,
        refreshToken,
        expiresAt,
        sessionId,
        refreshTokenId,
        tokenFamilyId,
        deviceId,
      );
}

/// Result of a token refresh operation (hook for future backend integration).
@immutable
class AuthTokenRefreshResult {
  const AuthTokenRefreshResult({
    required this.tokens,
    this.refreshedAt,
  });

  final AuthTokens tokens;
  final DateTime? refreshedAt;
}

/// Callback invoked by [AuthInterceptor] when access token expires.
typedef TokenRefreshCallback = Future<AuthTokens?> Function(String refreshToken);
