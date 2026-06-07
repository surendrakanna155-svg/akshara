import '../../repositories/api/admissions/remote/admissions_api_paths.dart';
import '../../repositories/api/auth/remote/auth_api_paths.dart';
import '../../repositories/api/audit/remote/audit_api_paths.dart';
import '../../repositories/api/finance/remote/finance_api_paths.dart';
import '../../repositories/api/hr/remote/hr_api_paths.dart';
import '../../repositories/api/sis/remote/sis_api_paths.dart';
import '../../repositories/api/transport/remote/transport_api_paths.dart';
import 'openapi_schema.dart';

/// Maps live API paths to response/request schemas from `openapi/akshara-erp-v1.yaml`.
abstract final class OpenApiContractRegistry {
  static const kpiItem = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['id', 'value', 'label'],
    properties: {
      'id': OpenApiSchema.string,
      'value': OpenApiSchema.string,
      'label': OpenApiSchema.string,
      'accentName': OpenApiSchema.string,
      'detail': OpenApiSchema.string,
    },
  );

  static const dashboardEnvelope = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['data'],
    properties: {
      'data': OpenApiSchema(
        type: OpenApiSchemaType.object,
        required: ['kpis'],
        properties: {
          'kpis': OpenApiSchema(
            type: OpenApiSchemaType.array,
            items: kpiItem,
          ),
        },
      ),
    },
  );

  static const permissionItem = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['permission'],
    properties: {
      'permission': OpenApiSchema.string,
      'source': OpenApiSchema.string,
    },
  );

  static const authPermissionsEnvelope = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['data'],
    properties: {
      'data': OpenApiSchema(
        type: OpenApiSchemaType.object,
        required: ['permissions'],
        properties: {
          'permissions': OpenApiSchema(
            type: OpenApiSchemaType.array,
            items: permissionItem,
          ),
        },
      ),
    },
  );

  static const authUserEnvelope = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['data'],
    properties: {
      'data': OpenApiSchema(
        type: OpenApiSchemaType.object,
        required: ['id', 'displayName', 'role'],
        properties: {
          'id': OpenApiSchema.string,
          'displayName': OpenApiSchema.string,
          'role': OpenApiSchema.string,
          'tenantId': OpenApiSchema.string,
          'schoolId': OpenApiSchema.string,
          'organizationId': OpenApiSchema.string,
          'email': OpenApiSchema.string,
        },
      ),
    },
  );

  static const auditEventPayload = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['id', 'type', 'timestamp'],
    properties: {
      'id': OpenApiSchema.string,
      'type': OpenApiSchema.string,
      'timestamp': OpenApiSchema(format: 'date-time', type: OpenApiSchemaType.string),
      'userId': OpenApiSchema.string,
      'tenantId': OpenApiSchema.string,
      'schoolId': OpenApiSchema.string,
      'correlationId': OpenApiSchema.string,
      'category': OpenApiSchema.string,
      'metadata': OpenApiSchema(
        type: OpenApiSchemaType.object,
        additionalProperties: true,
      ),
    },
  );

  static const auditBatchUploadRequest = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['events'],
    properties: {
      'events': OpenApiSchema(
        type: OpenApiSchemaType.array,
        minItems: 1,
        items: auditEventPayload,
      ),
    },
  );

  static const auditBatchUploadResponse = OpenApiSchema(
    type: OpenApiSchemaType.object,
    required: ['data'],
    properties: {
      'data': OpenApiSchema(
        type: OpenApiSchemaType.object,
        required: ['acceptedCount'],
        properties: {
          'acceptedCount': OpenApiSchema(type: OpenApiSchemaType.integer),
          'rejectedIds': OpenApiSchema(
            type: OpenApiSchemaType.array,
            items: OpenApiSchema.string,
          ),
        },
      ),
    },
  );

  static const responseSchemas = {
    AuthApiPaths.permissions: authPermissionsEnvelope,
    AuthApiPaths.me: authUserEnvelope,
    AdmissionsApiPaths.dashboard: dashboardEnvelope,
    FinanceApiPaths.dashboard: dashboardEnvelope,
    SisApiPaths.dashboard: dashboardEnvelope,
    HrApiPaths.dashboard: dashboardEnvelope,
    TransportApiPaths.dashboard: dashboardEnvelope,
    AuditApiPaths.batch: auditBatchUploadResponse,
  };

  static const requestSchemas = {
    AuditApiPaths.batch: auditBatchUploadRequest,
  };

  static OpenApiSchema? responseSchemaForPath(String path) => responseSchemas[path];

  static OpenApiSchema? requestSchemaForPath(String path) => requestSchemas[path];
}
