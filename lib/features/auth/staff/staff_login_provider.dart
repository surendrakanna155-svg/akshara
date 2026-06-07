import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository_providers.dart';
import '../../../core/auth/jwt_decoder.dart';
import '../../../core/repositories/interfaces/auth_repository.dart';
import '../../../core/security/erp_role.dart';
import '../auth_claims.dart';
import '../auth_token_models.dart';

/// Identifier type for staff login.
enum StaffLoginIdentifierType {
  email,
  mobile,
}

/// OTP workflow abstraction — swap implementation when auth API deploys.
abstract class StaffOtpWorkflow {
  Future<StaffOtpSendResult> sendOtp(StaffLoginRequest request);
  Future<StaffAuthResult?> verifyOtp(StaffOtpVerifyRequest request);
}

class StaffLoginRequest {
  const StaffLoginRequest({
    required this.identifier,
    required this.type,
    this.erpRole = ErpRole.superAdmin,
    this.rememberSession = true,
  });

  final String identifier;
  final StaffLoginIdentifierType type;
  final ErpRole erpRole;
  final bool rememberSession;
}

class StaffOtpVerifyRequest {
  const StaffOtpVerifyRequest({
    required this.identifier,
    required this.type,
    required this.otp,
    this.erpRole = ErpRole.superAdmin,
    this.rememberSession = true,
  });

  final String identifier;
  final StaffLoginIdentifierType type;
  final String otp;
  final ErpRole erpRole;
  final bool rememberSession;
}

class StaffOtpSendResult {
  const StaffOtpSendResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class StaffAuthResult {
  const StaffAuthResult({
    required this.displayName,
    required this.tokens,
    required this.claims,
    required this.rememberSession,
  });

  final String displayName;
  final AuthTokens tokens;
  final AuthClaims claims;
  final bool rememberSession;
}

/// Mock OTP workflow for development (no backend yet).
class MockStaffOtpWorkflow implements StaffOtpWorkflow {
  const MockStaffOtpWorkflow();

  static const validOtp = '654321';

  @override
  Future<StaffOtpSendResult> sendOtp(StaffLoginRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_isValidIdentifier(request.identifier, request.type)) {
      return const StaffOtpSendResult(
        success: false,
        message: 'Enter a valid email or 10-digit mobile number.',
      );
    }
    return const StaffOtpSendResult(success: true);
  }

  @override
  Future<StaffAuthResult?> verifyOtp(StaffOtpVerifyRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final otp = request.otp.trim();
    final isValid = otp == validOtp ||
        (otp.length == 6 && int.tryParse(otp) != null);
    if (!isValid) return null;

    final userId = 'staff_${_normalize(request.identifier)}';
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final accessToken = JwtDecoder.buildMockToken(
      subject: userId,
      tenantId: 'tenant_demo_001',
      schoolId: 'school_akshara_001',
      organizationId: 'org_akshara_001',
      role: request.erpRole.name,
      ttl: const Duration(hours: 1),
    );

    final tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: 'staff_refresh_${expiresAt.millisecondsSinceEpoch}',
      expiresAt: expiresAt,
    );

    final claims = AuthClaims(
      userId: userId,
      erpRole: request.erpRole,
      tenantId: 'tenant_demo_001',
      schoolId: 'school_akshara_001',
      organizationId: 'org_akshara_001',
      accessTokenExpiresAt: expiresAt,
    );

    return StaffAuthResult(
      displayName: _displayNameFor(request.identifier, request.type),
      tokens: tokens,
      claims: claims,
      rememberSession: request.rememberSession,
    );
  }

  bool _isValidIdentifier(String raw, StaffLoginIdentifierType type) {
    final value = raw.trim();
    return switch (type) {
      StaffLoginIdentifierType.mobile =>
        value.replaceAll(RegExp(r'\D'), '').length == 10,
      StaffLoginIdentifierType.email =>
        RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value),
    };
  }

  String _normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\D'), '').toLowerCase();

  String _displayNameFor(String identifier, StaffLoginIdentifierType type) {
    if (type == StaffLoginIdentifierType.email) {
      final local = identifier.split('@').first;
      return local.isEmpty ? 'Staff User' : local;
    }
    return 'Staff User';
  }
}

/// Repository-backed OTP workflow for production auth server.
class ApiStaffOtpWorkflow implements StaffOtpWorkflow {
  ApiStaffOtpWorkflow(this._repository);

  final AuthRepository _repository;

  @override
  Future<StaffOtpSendResult> sendOtp(StaffLoginRequest request) async {
    final session = await _repository.login(
      request.identifier,
      identifierType: request.type.name,
    );
    return StaffOtpSendResult(
      success: session.success,
      message: session.message,
    );
  }

  @override
  Future<StaffAuthResult?> verifyOtp(StaffOtpVerifyRequest request) async {
    final result = await _repository.verifyOtp(
      request.identifier,
      request.otp,
      identifierType: request.type.name,
    );
    if (result == null) return null;

    final claims = AuthClaims(
      userId: result.user.id,
      erpRole: result.user.erpRole,
      tenantId: result.user.tenantId,
      schoolId: result.user.schoolId,
      organizationId: result.user.organizationId,
      permissions: [
        for (final entry in result.permissions) entry.permission,
      ],
      accessTokenExpiresAt: result.tokens.expiresAt,
    );

    return StaffAuthResult(
      displayName: result.user.displayName,
      tokens: result.tokens,
      claims: claims,
      rememberSession: request.rememberSession,
    );
  }
}

final staffOtpWorkflowProvider = Provider<StaffOtpWorkflow>((ref) {
  if (isAuthApiEnabled(ref)) {
    return ApiStaffOtpWorkflow(ref.watch(authRepositoryProvider));
  }
  return const MockStaffOtpWorkflow();
});

enum StaffLoginStatus {
  idle,
  sendingOtp,
  otpPending,
  verifying,
  error,
}

class StaffLoginState {
  const StaffLoginState({
    this.status = StaffLoginStatus.idle,
    this.identifier = '',
    this.identifierType = StaffLoginIdentifierType.email,
    this.selectedRole = ErpRole.superAdmin,
    this.rememberSession = true,
    this.errorMessage,
  });

  final StaffLoginStatus status;
  final String identifier;
  final StaffLoginIdentifierType identifierType;
  final ErpRole selectedRole;
  final bool rememberSession;
  final String? errorMessage;

  bool get isLoading =>
      status == StaffLoginStatus.sendingOtp ||
      status == StaffLoginStatus.verifying;

  StaffLoginState copyWith({
    StaffLoginStatus? status,
    String? identifier,
    StaffLoginIdentifierType? identifierType,
    ErpRole? selectedRole,
    bool? rememberSession,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StaffLoginState(
      status: status ?? this.status,
      identifier: identifier ?? this.identifier,
      identifierType: identifierType ?? this.identifierType,
      selectedRole: selectedRole ?? this.selectedRole,
      rememberSession: rememberSession ?? this.rememberSession,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class StaffLoginNotifier extends Notifier<StaffLoginState> {
  @override
  StaffLoginState build() => const StaffLoginState();

  void setIdentifierType(StaffLoginIdentifierType type) {
    state = state.copyWith(identifierType: type, clearError: true);
  }

  void setSelectedRole(ErpRole role) {
    state = state.copyWith(selectedRole: role, clearError: true);
  }

  void setRememberSession(bool value) {
    state = state.copyWith(rememberSession: value);
  }

  Future<bool> sendOtp(String identifier) async {
    state = state.copyWith(
      status: StaffLoginStatus.sendingOtp,
      identifier: identifier.trim(),
      clearError: true,
    );

    final workflow = ref.read(staffOtpWorkflowProvider);
    final result = await workflow.sendOtp(
      StaffLoginRequest(
        identifier: state.identifier,
        type: state.identifierType,
        erpRole: state.selectedRole,
        rememberSession: state.rememberSession,
      ),
    );

    if (!result.success) {
      state = state.copyWith(
        status: StaffLoginStatus.error,
        errorMessage: result.message ?? 'Unable to send OTP.',
      );
      return false;
    }

    state = state.copyWith(status: StaffLoginStatus.otpPending, clearError: true);
    return true;
  }

  Future<StaffAuthResult?> verifyOtp(String otp) async {
    state = state.copyWith(status: StaffLoginStatus.verifying, clearError: true);

    final workflow = ref.read(staffOtpWorkflowProvider);
    final result = await workflow.verifyOtp(
      StaffOtpVerifyRequest(
        identifier: state.identifier,
        type: state.identifierType,
        otp: otp,
        erpRole: state.selectedRole,
        rememberSession: state.rememberSession,
      ),
    );

    if (result == null) {
      final hint = isAuthApiEnabled(ref)
          ? 'Invalid OTP. Please try again.'
          : 'Invalid OTP. Try ${MockStaffOtpWorkflow.validOtp}.';
      state = state.copyWith(
        status: StaffLoginStatus.error,
        errorMessage: hint,
      );
      return null;
    }

    state = state.copyWith(status: StaffLoginStatus.idle, clearError: true);
    return result;
  }

  void reset() {
    state = const StaffLoginState();
  }
}

final staffLoginProvider =
    NotifierProvider<StaffLoginNotifier, StaffLoginState>(
  StaffLoginNotifier.new,
);
