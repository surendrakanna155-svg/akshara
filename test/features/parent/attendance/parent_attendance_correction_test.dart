import 'package:akshara_erp/core/attendance/attendance_correction_store.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/parent/parent_mutations_provider.dart';
import 'package:akshara_erp/features/parent/parent_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    AttendanceCorrectionStore.instance.reset();
  });

  group('submitParentAttendanceCorrection', () {
    test('succeeds for parent role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.parent),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(submitParentAttendanceCorrectionProvider.notifier)
          .execute(
            const ParentAttendanceCorrectionRequest(
              childName: 'Ravi Kumar',
              classLabel: '8-A',
              dateLabel: '5 Jun 2026',
              fromMark: 'Absent',
              toMark: 'Present',
              reason: 'Student attended school',
            ),
          );

      expect(result, isNotNull);
      expect(AttendanceCorrectionStore.instance.listAll(), hasLength(1));
    });
  });
}
