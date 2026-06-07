import 'dart:convert';

import '../../features/auth/auth_token_models.dart';

/// Detects refresh-token reuse (possible token theft).
enum RefreshRotationStatus {
  initial,
  rotated,
  reuseDetected,
}

/// Result of recording a refresh-token rotation.
class RefreshRotationResult {
  const RefreshRotationResult({
    required this.status,
    this.previousHash,
    this.currentHash,
  });

  final RefreshRotationStatus status;
  final String? previousHash;
  final String? currentHash;

  bool get isReuseDetected => status == RefreshRotationStatus.reuseDetected;
}

/// Tracks refresh-token hashes and token families across rotations.
class RefreshTokenRotationTracker {
  String? _activeRefreshTokenHash;
  String? _tokenFamilyId;
  final Set<String> _spentRefreshTokenHashes = {};

  String? get activeRefreshTokenHash => _activeRefreshTokenHash;
  String? get tokenFamilyId => _tokenFamilyId;

  /// Returns `true` when [tokens] present a refresh token already spent.
  bool detectReuse(AuthTokens tokens) {
    if (tokens.refreshToken.isEmpty) return false;
    final hash = hashRefreshToken(tokens.refreshToken);
    return _spentRefreshTokenHashes.contains(hash) &&
        hash != _activeRefreshTokenHash;
  }

  /// Seeds the tracker with the initial refresh token on login.
  void seed(AuthTokens tokens) {
    if (tokens.refreshToken.isEmpty) return;
    _activeRefreshTokenHash = hashRefreshToken(tokens.refreshToken);
    _tokenFamilyId = tokens.tokenFamilyId;
    _spentRefreshTokenHashes.clear();
  }

  /// Records a successful refresh rotation from [previous] to [next].
  RefreshRotationResult recordRotation({
    required AuthTokens previous,
    required AuthTokens next,
  }) {
    final previousHash = hashRefreshToken(previous.refreshToken);
    final nextHash = hashRefreshToken(next.refreshToken);
    final familyId = next.tokenFamilyId ?? previous.tokenFamilyId;

    if (_spentRefreshTokenHashes.contains(previousHash) &&
        previousHash != _activeRefreshTokenHash) {
      return RefreshRotationResult(
        status: RefreshRotationStatus.reuseDetected,
        previousHash: previousHash,
        currentHash: nextHash,
      );
    }

    final status = _activeRefreshTokenHash == null
        ? RefreshRotationStatus.initial
        : RefreshRotationStatus.rotated;

    _spentRefreshTokenHashes.add(previousHash);
    _activeRefreshTokenHash = nextHash;
    _tokenFamilyId = familyId;

    return RefreshRotationResult(
      status: status,
      previousHash: previousHash,
      currentHash: nextHash,
    );
  }

  void reset() {
    _activeRefreshTokenHash = null;
    _tokenFamilyId = null;
    _spentRefreshTokenHashes.clear();
  }

  /// Stable hash for refresh-token comparison (not for cryptographic security).
  static String hashRefreshToken(String token) {
    return base64Url.encode(utf8.encode(token));
  }
}
