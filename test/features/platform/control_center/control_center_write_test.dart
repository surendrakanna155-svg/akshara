import 'package:akshara_erp/core/repositories/mock/mock_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_control_center_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_models.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_mutations_provider.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockControlCenterWriteStore.instance.reset();
  });

  group('Control center mock writes', () {
    const query = RepositoryQuery.demo;

    test('createSchool inserts a trial, zero-MRR school', () async {
      final repo = MockControlCenterRepository();
      final before = await repo.getSchools(query: query);

      final school = await repo.createSchool(
        query: query,
        request: const CreateSchoolRequest(
          name: 'Riverdale Global School',
          plan: 'Premium',
          region: 'East',
          studentCount: '1500',
        ),
      );

      final after = await repo.getSchools(query: query);
      expect(after.total, before.total + 1);
      expect(school.status, PlatformSchoolStatus.trial);
      expect(school.plan, SubscriptionPlan.premium);
      expect(school.studentCount, 1500);
      expect(school.mrrLakhs, 0);
      expect(after.items.any((s) => s.id == school.id), isTrue);
    });

    test('createSchool defaults to the standard plan for unknown text',
        () async {
      final repo = MockControlCenterRepository();

      final school = await repo.createSchool(
        query: query,
        request: const CreateSchoolRequest(
          name: 'Greenfield Academy',
          plan: '',
          region: '',
          studentCount: '',
        ),
      );

      expect(school.plan, SubscriptionPlan.standard);
      expect(school.studentCount, 0);
      expect(school.region, '—');
    });

    test('createSchool rejects an empty name', () async {
      final repo = MockControlCenterRepository();

      expect(
        () => repo.createSchool(
          query: query,
          request: const CreateSchoolRequest(
            name: '  ',
            plan: '',
            region: '',
            studentCount: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('createLead inserts a lead-stage deal into the pipeline', () async {
      final repo = MockControlCenterRepository();
      final before = await repo.getCrmPipeline(query: query);

      final deal = await repo.createLead(
        query: query,
        request: const CreateCrmLeadRequest(
          schoolName: 'Horizon World School',
          contactName: 'Neha Kapoor',
          owner: 'Anita Sales',
          estimatedMrr: '4.5',
        ),
      );

      final after = await repo.getCrmPipeline(query: query);
      expect(after.deals.length, before.deals.length + 1);
      expect(deal.stage, CrmPipelineStage.lead);
      expect(deal.estimatedMrrLakhs, 4.5);
      expect(after.deals.any((d) => d.id == deal.id), isTrue);
    });

    test('createLead defaults owner and MRR when blank', () async {
      final repo = MockControlCenterRepository();

      final deal = await repo.createLead(
        query: query,
        request: const CreateCrmLeadRequest(
          schoolName: 'Unassigned Lead School',
          contactName: '',
          owner: '',
          estimatedMrr: '',
        ),
      );

      expect(deal.owner, 'Unassigned');
      expect(deal.estimatedMrrLakhs, 0);
      expect(deal.contactName, '—');
    });

    test('createLead rejects an empty school name', () async {
      final repo = MockControlCenterRepository();

      expect(
        () => repo.createLead(
          query: query,
          request: const CreateCrmLeadRequest(
            schoolName: '  ',
            contactName: '',
            owner: '',
            estimatedMrr: '',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('Control center RBAC mutations', () {
    test('createSchool fails without manageControlCenter', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createSchoolProvider.notifier).execute(
            const CreateSchoolRequest(
              name: 'Blocked School',
              plan: '',
              region: '',
              studentCount: '',
            ),
          );

      expect(container.read(createSchoolProvider).hasError, isTrue);
    });

    test('createSchool succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createSchoolProvider.notifier).execute(
            const CreateSchoolRequest(
              name: 'Allowed School',
              plan: 'Enterprise',
              region: 'North',
              studentCount: '3000',
            ),
          );

      expect(container.read(createSchoolProvider).hasValue, isTrue);
      expect(
        container.read(createSchoolProvider).value?.status,
        PlatformSchoolStatus.trial,
      );
    });

    test('createLead fails without manageControlCenter', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createCrmLeadProvider.notifier).execute(
            const CreateCrmLeadRequest(
              schoolName: 'Blocked Lead',
              contactName: '',
              owner: '',
              estimatedMrr: '',
            ),
          );

      expect(container.read(createCrmLeadProvider).hasError, isTrue);
    });

    test('createLead succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createCrmLeadProvider.notifier).execute(
            const CreateCrmLeadRequest(
              schoolName: 'Allowed Lead',
              contactName: 'Priya Nair',
              owner: 'Vikram Sales',
              estimatedMrr: '2.0',
            ),
          );

      expect(container.read(createCrmLeadProvider).hasValue, isTrue);
      expect(
        container.read(createCrmLeadProvider).value?.stage,
        CrmPipelineStage.lead,
      );
    });
  });
}
