import 'package:dio/dio.dart';

import '../../network/api_config.dart';
import '../../tenant/tenant_context.dart';

/// Supplies tenant, organization, and user identifiers on every API request.
class TenantInterceptor extends Interceptor {
  TenantInterceptor({
    required this.tenantAccessor,
    this.requireTenant = true,
  });

  /// Returns the active tenant context, or null for anonymous requests.
  final TenantContext? Function() tenantAccessor;

  /// When true, rejects requests missing a valid tenant id.
  final bool requireTenant;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final tenant = tenantAccessor();

    if (requireTenant && (tenant == null || tenant.tenantId.isEmpty)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Tenant context required',
        ),
      );
      return;
    }

    if (tenant != null) {
      options.headers[ApiConfig.tenantIdHeader] = tenant.tenantId;

      if (tenant.schoolId != null && tenant.schoolId!.isNotEmpty) {
        options.headers[ApiConfig.schoolIdHeader] = tenant.schoolId;
      }

      if (tenant.organizationId != null &&
          tenant.organizationId!.isNotEmpty) {
        options.headers[ApiConfig.organizationIdHeader] = tenant.organizationId;
      }

      if (tenant.userId.isNotEmpty) {
        options.headers[ApiConfig.userIdHeader] = tenant.userId;
      }
    }

    handler.next(options);
  }
}
