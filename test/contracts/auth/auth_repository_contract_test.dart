import 'package:akshara_erp/core/repositories/api/auth/dto/auth_permissions_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/api_auth_repository.dart';
import 'package:akshara_erp/core/repositories/api/auth/dto/auth_login_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/dto/auth_permissions_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/dto/auth_tokens_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/dto/auth_user_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/dto/auth_verify_otp_dto.dart';
import 'package:akshara_erp/core/repositories/api/auth/mapper/auth_mapper.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/auth_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_auth_repository.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fixture_builder.dart';

const _fixtures = AuthFixtureBuilder();
const _mapper = AuthMapper();

void main() {
  group('Auth repository contract', () {
    late MockAuthRepository mockRepo;
    late ApiAuthRepository apiRepo;

    setUp(() {
      mockRepo = const MockAuthRepository();
      apiRepo = ApiAuthRepository(
        remote: AuthRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement AuthRepository', () {
      expect(mockRepo, isA<AuthRepository>());
      expect(apiRepo, isA<AuthRepository>());
    });

    test('login DTO mapping', () {
      final mapped = _mapper.toLoginSession(
        AuthLoginDto.fromJson(_fixtures.loginEnvelope()),
      );
      expect(mapped.success, isTrue);
      expect(mapped.sessionId, 'session_001');
    });

    test('verify OTP DTO mapping', () {
      final mapped = _mapper.toVerificationResult(
        AuthVerifyOtpDto.fromJson(_fixtures.verifyOtpEnvelope()),
      );
      expect(mapped.user.id, 'staff_api_001');
      expect(mapped.user.erpRole, ErpRole.superAdmin);
      expect(mapped.tokens.accessToken, isNotEmpty);
      expect(mapped.permissions.first.permission, Permission.viewAdminHub);
    });

    test('tokens DTO mapping', () {
      final mapped = _mapper.toTokens(
        AuthTokensDto.fromJson(_fixtures.tokensEnvelope()),
      );
      expect(mapped.accessToken, isNotEmpty);
      expect(mapped.refreshToken, 'refresh_token');
    });

    test('user DTO mapping', () {
      final mapped = _mapper.toUser(
        AuthUserDto.fromJson(_fixtures.userEnvelope(role: ErpRole.financeAdmin)),
      );
      expect(mapped.erpRole, ErpRole.financeAdmin);
      expect(mapped.displayName, 'Finance Staff');
    });

    test('permissions DTO mapping', () {
      final mapped = _mapper.toServerPermissions(
        AuthPermissionsDto.fromJson(_fixtures.permissionsEnvelope()),
      );
      expect(mapped.length, 2);
      expect(mapped.first.permission, Permission.viewFinance);
    });

    test('permissions DTO mapping includes version metadata', () {
      final dto = AuthPermissionsDto.fromJson(_fixtures.permissionsEnvelope());
      expect(dto.permissionsVersion, 3);
      expect(dto.syncedAt, isNotNull);
      final policy = _mapper.toPermissionPolicyFromDto(
        dto: dto,
        userId: 'staff_api_001',
        tenantId: 'tenant_demo_001',
      );
      expect(policy.version, 3);
    });

    test('mock login accepts valid email', () async {
      final session = await mockRepo.login('staff@school.edu');
      expect(session.success, isTrue);
    });

    test('mock verify OTP accepts valid code', () async {
      final result = await mockRepo.verifyOtp(
        'staff@school.edu',
        MockAuthRepository.validOtp,
      );
      expect(result, isNotNull);
      expect(result!.user.erpRole, ErpRole.superAdmin);
    });

    test('mock refresh returns tokens', () async {
      final tokens = await mockRepo.refreshToken('refresh_abc');
      expect(tokens, isNotNull);
      expect(tokens!.accessToken, isNotEmpty);
    });
  });
}
