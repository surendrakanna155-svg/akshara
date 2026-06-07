import '../../../audit/audit_event.dart';
import '../../interfaces/auth_repository.dart';
import '../../../../../features/auth/auth_token_models.dart';
import 'mapper/auth_mapper.dart';
import 'remote/auth_remote_datasource.dart';

typedef AuthRepositoryAuditHook = void Function(
  AuditEventType type, {
  Map<String, String>? metadata,
});

/// API implementation of [AuthRepository] — enabled via [authApiEnabledProvider].
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required AuthRemoteDataSource remote,
    AuthMapper mapper = const AuthMapper(),
    AuthRepositoryAuditHook? onAudit,
  })  : _remote = remote,
        _mapper = mapper,
        _onAudit = onAudit;

  final AuthRemoteDataSource _remote;
  final AuthMapper _mapper;
  final AuthRepositoryAuditHook? _onAudit;

  @override
  Future<AuthSession> login(
    String identifier, {
    String identifierType = 'email',
  }) async {
    final dto = await _remote.login(
      identifier: identifier,
      identifierType: identifierType,
    );
    return _mapper.toLoginSession(dto);
  }

  @override
  Future<AuthVerificationResult?> verifyOtp(
    String identifier,
    String otp, {
    String identifierType = 'email',
  }) async {
    try {
      final dto = await _remote.verifyOtp(
        identifier: identifier,
        otp: otp,
        identifierType: identifierType,
      );
      final result = _mapper.toVerificationResult(dto);
      if (result.tokens.accessToken.isEmpty) return null;
      _onAudit?.call(
        AuditEventType.login,
        metadata: {'userId': result.user.id},
      );
      return result;
    } on Object {
      return null;
    }
  }

  @override
  Future<AuthTokens?> refreshToken(String refreshToken) async {
    if (refreshToken.isEmpty) return null;
    try {
      final dto = await _remote.refreshToken(refreshToken: refreshToken);
      final tokens = _mapper.toTokens(dto);
      if (tokens.accessToken.isEmpty) return null;
      _onAudit?.call(AuditEventType.tokenRefresh);
      return tokens;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } on Object {
      // Local session cleanup proceeds even when server logout fails.
    }
    _onAudit?.call(AuditEventType.logout);
  }

  @override
  Future<AuthUser> getCurrentUser() async {
    final dto = await _remote.fetchCurrentUser();
    return _mapper.toUser(dto);
  }

  @override
  Future<List<ServerPermission>> getPermissions() async {
    final dto = await _remote.fetchPermissions();
    return _mapper.toServerPermissions(dto);
  }
}
