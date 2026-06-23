import 'package:akshara_erp/core/repositories/mock/mock_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_alumni_write_store.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/alumni/alumni_models.dart';
import 'package:akshara_erp/features/alumni/alumni_mutations_provider.dart';
import 'package:akshara_erp/features/alumni/alumni_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    MockAlumniWriteStore.instance.reset();
  });

  group('Alumni mock writes', () {
    const query = RepositoryQuery.demo;

    test('addAlumni inserts an active, SIS-unlinked record', () async {
      final repo = MockAlumniRepository();
      final before = await repo.getAlumniRegistry(query: query);

      final alumni = await repo.addAlumni(
        query: query,
        request: const AddAlumniRequest(
          name: 'Meera Iyer',
          batchYear: '2011',
          program: 'Class 12 — Commerce',
          currentRole: 'Chartered Accountant',
          city: 'Chennai',
          email: 'meera.iyer@example.com',
          phone: '+91 90000 00000',
        ),
      );

      final after = await repo.getAlumniRegistry(query: query);
      expect(after.total, before.total + 1);
      expect(alumni.engagementStatus, AlumniEngagementStatus.active);
      expect(alumni.sisStudentId, '');
      expect(after.items.any((a) => a.id == alumni.id), isTrue);
    });

    test('addAlumni rejects an empty name', () async {
      final repo = MockAlumniRepository();

      expect(
        () => repo.addAlumni(
          query: query,
          request: const AddAlumniRequest(
            name: '  ',
            batchYear: '2011',
            program: '',
            currentRole: '',
            city: '',
            email: '',
            phone: '',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('Alumni RBAC mutations', () {
    test('addAlumni fails without manageAlumni', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addAlumniProvider.notifier).execute(
            const AddAlumniRequest(
              name: 'Blocked Alumnus',
              batchYear: '2011',
              program: '',
              currentRole: '',
              city: '',
              email: '',
              phone: '',
            ),
          );

      expect(container.read(addAlumniProvider).hasError, isTrue);
    });

    test('addAlumni succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addAlumniProvider.notifier).execute(
            const AddAlumniRequest(
              name: 'Allowed Alumnus',
              batchYear: '2012',
              program: '',
              currentRole: '',
              city: '',
              email: '',
              phone: '',
            ),
          );

      expect(container.read(addAlumniProvider).hasValue, isTrue);
      expect(
        container.read(addAlumniProvider).value?.engagementStatus,
        AlumniEngagementStatus.active,
      );
    });
  });
}
