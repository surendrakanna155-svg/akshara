import 'package:dio/dio.dart';

import '../dto/auth_login_dto.dart';
import '../dto/auth_permissions_dto.dart';
import '../dto/auth_tokens_dto.dart';
import '../dto/auth_user_dto.dart';
import '../dto/auth_verify_otp_dto.dart';
import 'auth_api_paths.dart';

/// Dio-backed remote data source for Auth.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthLoginDto> login({
    required String identifier,
    required String identifierType,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AuthApiPaths.login,
      data: {
        'identifier': identifier,
        'type': identifierType,
      },
    );
    return AuthLoginDto.fromJson(_responseMap(response));
  }

  Future<AuthVerifyOtpDto> verifyOtp({
    required String identifier,
    required String otp,
    required String identifierType,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AuthApiPaths.verifyOtp,
      data: {
        'identifier': identifier,
        'otp': otp,
        'type': identifierType,
      },
    );
    return AuthVerifyOtpDto.fromJson(_responseMap(response));
  }

  Future<AuthTokensDto> refreshToken({required String refreshToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AuthApiPaths.refresh,
      data: {'refreshToken': refreshToken},
    );
    return AuthTokensDto.fromJson(_responseMap(response));
  }

  Future<void> logout() async {
    await _dio.post<void>(AuthApiPaths.logout);
  }

  Future<void> revokeSession({required String sessionId}) async {
    await _dio.post<void>(
      AuthApiPaths.revokeSession,
      data: {'sessionId': sessionId},
    );
  }

  Future<void> logoutAllSessions() async {
    await _dio.post<void>(AuthApiPaths.logoutAllSessions);
  }

  Future<AuthUserDto> fetchCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(AuthApiPaths.me);
    return AuthUserDto.fromJson(_responseMap(response));
  }

  Future<AuthPermissionsDto> fetchPermissions() async {
    final response =
        await _dio.get<Map<String, dynamic>>(AuthApiPaths.permissions);
    return AuthPermissionsDto.fromJson(_responseMap(response));
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
