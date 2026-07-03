import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../phase5/phase5_providers.dart';
import 'operations_hub_pdf_service.dart';

void assertManageOperationsHub(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  final canManage = permissions?.has(Permission.manageManagement) == true &&
      permissions?.has(Permission.viewOperationsHub) == true;
  if (!canManage) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage Operations Hub actions.',
        code: 'RBAC_MANAGE_OPERATIONS_HUB',
      ),
    );
  }
}

class DismissOperationsAlertNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute(String alertId) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOperationsHub(ref);
      try {
        await ref.read(operationsHubRepositoryProvider).dismissAlert(
              query: ref.read(repositoryQueryProvider),
              alertId: alertId,
            );
        ref.invalidate(operationsHubProvider);
        return alertId;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final dismissOperationsAlertProvider =
    AsyncNotifierProvider<DismissOperationsAlertNotifier, String?>(
  DismissOperationsAlertNotifier.new,
);

class CompleteOperationsActionNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute(String actionId) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageOperationsHub(ref);
      try {
        await ref.read(operationsHubRepositoryProvider).completeAction(
              query: ref.read(repositoryQueryProvider),
              actionId: actionId,
            );
        ref.invalidate(operationsHubProvider);
        return actionId;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final completeOperationsActionProvider =
    AsyncNotifierProvider<CompleteOperationsActionNotifier, String?>(
  CompleteOperationsActionNotifier.new,
);

final operationsHubPdfServiceProvider = Provider<OperationsHubPdfService>(
  (ref) => const OperationsHubPdfService(),
);

/// PRI-3 — read authority for exporting the daily school report. Any hub viewer
/// may export the snapshot they can already see (read-only report).
void assertViewOperationsHub(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions?.has(Permission.viewOperationsHub) != true) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to view the Operations Hub.',
        code: 'RBAC_VIEW_OPERATIONS_HUB',
      ),
    );
  }
}

/// PRI-3 — build the "Daily school report" PDF from the current ops-hub
/// snapshot. Returns null on failure; the screen shows print / share on success.
class ExportOperationsHubReportNotifier extends AsyncNotifier<Uint8List?> {
  @override
  FutureOr<Uint8List?> build() => null;

  Future<Uint8List?> execute() async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertViewOperationsHub(ref);
      try {
        final snapshot = await ref.read(operationsHubProvider.future);
        final now = DateTime.now();
        final dateLabel =
            '${now.year}-${_two(now.month)}-${_two(now.day)}';
        return await ref.read(operationsHubPdfServiceProvider).buildDailyReportPdf(
              schoolName: 'Akshara International School',
              dateLabel: dateLabel,
              snapshot: snapshot,
            );
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    if (state.hasError) throw state.error!;
    return state.valueOrNull;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

final exportOperationsHubReportProvider =
    AsyncNotifierProvider<ExportOperationsHubReportNotifier, Uint8List?>(
  ExportOperationsHubReportNotifier.new,
);
