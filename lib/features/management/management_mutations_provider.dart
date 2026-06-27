import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'management_audit.dart';
import 'management_models.dart';
import 'management_providers.dart';
import 'management_requests.dart';
import 'reports/management_dashboard_pdf_service.dart';

void assertManageManagement(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageManagement)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage executive approvals.',
        code: 'RBAC_MANAGE_MANAGEMENT',
      ),
    );
  }
}

class ResolveManagementApprovalNotifier
    extends AsyncNotifier<ManagementApprovalItem?> {
  @override
  FutureOr<ManagementApprovalItem?> build() => null;

  Future<ManagementApprovalItem?> execute(
    ResolveManagementApprovalRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageManagement(ref);
      try {
        final result = await ref
            .read(managementRepositoryProvider)
            .resolveManagementApproval(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        await recordManagementAudit(
          ref,
          type: AuditEventType.leadUpdated,
          action: 'resolveManagementApproval',
          entityId: request.approvalId,
          metadata: {'status': request.status.name},
        );
        ref
          ..invalidate(managementTasksFutureProvider)
          ..invalidate(managementDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final resolveManagementApprovalProvider = AsyncNotifierProvider<
    ResolveManagementApprovalNotifier, ManagementApprovalItem?>(
  ResolveManagementApprovalNotifier.new,
);

class UpdateManagementSettingsNotifier
    extends AsyncNotifier<ManagementSettingsData?> {
  @override
  FutureOr<ManagementSettingsData?> build() => null;

  Future<ManagementSettingsData?> execute(
    UpdateManagementSettingsRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageManagement(ref);
      try {
        final result =
            await ref.read(managementRepositoryProvider).updateSettings(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        await recordManagementAudit(
          ref,
          type: AuditEventType.leadUpdated,
          action: 'updateManagementSettings',
          entityId: 'managementSettings',
          metadata: {
            if (request.academicYear != null)
              'academicYear': request.academicYear!,
            'updatedItems': '${request.updates.length}',
          },
        );
        ref.invalidate(managementSettingsFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final updateManagementSettingsProvider = AsyncNotifierProvider<
    UpdateManagementSettingsNotifier, ManagementSettingsData?>(
  UpdateManagementSettingsNotifier.new,
);

final managementDashboardPdfServiceProvider =
    Provider<ManagementDashboardPdfService>(
  (ref) => const ManagementDashboardPdfService(),
);

class ExportManagementDashboardNotifier extends AsyncNotifier<Uint8List?> {
  @override
  FutureOr<Uint8List?> build() => null;

  Future<Uint8List?> execute() async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageManagement(ref);
      try {
        final query = ref.read(managementDashboardQueryProvider);
        final data = await ref.read(managementRepositoryProvider).getDashboard(
              query: query,
            );
        final periodLabel =
            _periodLabel(ref.read(managementDashboardFilterProvider));
        final bytes = await ref
            .read(managementDashboardPdfServiceProvider)
            .buildDashboardPdf(
              schoolName: 'Akshara International School',
              periodLabel: periodLabel,
              data: data,
            );
        await recordManagementAudit(
          ref,
          type: AuditEventType.receiptPdfExported,
          action: 'exportManagementDashboard',
          entityId: 'managementDashboard',
          metadata: {'period': periodLabel},
        );
        return bytes;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }

  String _periodLabel(int filterIndex) {
    return switch (filterIndex) {
      1 => 'Q1',
      2 => 'All quarters',
      _ => 'FY 2026-27',
    };
  }
}

final exportManagementDashboardProvider =
    AsyncNotifierProvider<ExportManagementDashboardNotifier, Uint8List?>(
  ExportManagementDashboardNotifier.new,
);
