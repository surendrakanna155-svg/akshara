import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_provider.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_api_paths.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_mutations_provider.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Admissions RBAC mutations', () {
    test('createLead fails when manageAdmissions permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.management),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createLeadProvider.notifier).execute(
            const CreateLeadRequest(
              parentName: 'A',
              studentName: 'B',
              classLabel: '5',
              phone: '9999999999',
            ),
          );

      expect(container.read(createLeadProvider).hasError, isTrue);
    });

    test('createLead fails for financeAdmin without manageAdmissions', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createLeadProvider.notifier).execute(
            const CreateLeadRequest(
              parentName: 'Finance Block',
              studentName: 'Student',
              classLabel: '5',
              phone: '8888888888',
            ),
          );

      expect(container.read(createLeadProvider).hasError, isTrue);
    });

    test('approveAdmission fails when approveAdmissions permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(approveAdmissionProvider.notifier).execute(
            approvalId: 'appr_1',
            request: const ApprovalDecisionRequest(comment: 'Should fail'),
          );

      expect(container.read(approveAdmissionProvider).hasError, isTrue);
    });
  });

  group('Admissions audit events', () {
    test('recordAdmissionsAudit stores entityId metadata', () async {
      final container = ProviderContainer(
        overrides: providerTestOverrides(),
      );
      addTearDown(container.dispose);

      await container.read(auditLoggerProvider).logTyped(
            type: AuditEventType.leadCreated,
            userId: 'user_test',
            tenantId: 'tenant_demo',
            metadata: const {'entityId': 'LD-9999'},
          );

      final events = await container.read(auditEventsProvider.future);
      expect(
        events.any(
          (event) =>
              event.type == AuditEventType.leadCreated &&
              event.metadata['entityId'] == 'LD-9999' &&
              event.tenantId != null,
        ),
        isTrue,
      );
    });
  });

  group('Admissions API write paths', () {
    test('maps resource ids to REST endpoints', () {
      expect(AdmissionsApiPaths.lead('LD-1'), '/admissions/leads/LD-1');
      expect(
        AdmissionsApiPaths.applicationSubmit('APP-1'),
        '/admissions/applications/APP-1/submit',
      );
      expect(
        AdmissionsApiPaths.documentApprove('DOC-1'),
        '/admissions/documents/DOC-1/approve',
      );
      expect(
        AdmissionsApiPaths.approvalApprove('APR-1'),
        '/admissions/approval/APR-1/approve',
      );
      expect(AdmissionsApiPaths.handoffsSend, '/admissions/handoffs/send');
    });
  });

  group('Mock write repository flows', () {
    test('sendToFinance updates handoff status', () async {
      final repo = MockAdmissionsRepository();
      const query = RepositoryQuery.demo;
      final handoffs = await repo.getApprovedHandoffs(query: query);
      final target = handoffs.items.first;
      final updated = await repo.sendToFinance(
        query: query,
        request: FinanceHandoffRequest(
          handoffId: target.id,
          feeStructureId: 'FS-001',
        ),
      );
      expect(updated.handoffStatus, FeeHandoffStatus.sentToFinance);
    });
  });
}
