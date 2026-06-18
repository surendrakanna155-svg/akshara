import 'package:akshara_erp/core/attendance/attendance_correction_store.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/teacher/teacher_mutations_provider.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
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

  group('submitAttendanceCorrection', () {
    test('succeeds for teacher role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.teacher),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(submitAttendanceCorrectionProvider.notifier)
          .execute(
            const TeacherAttendanceCorrectionRequest(
              sisStudentId: 'stu_8a_01',
              studentName: 'Arjun Patel',
              classLabel: '8',
              section: 'A',
              dateLabel: '12 Jun 2026',
              fromMark: 'Absent',
              toMark: 'Present',
              reason: 'Late arrival recorded as absent',
            ),
          );

      expect(result, isNotNull);
      expect(result!.correctionId, startsWith('att_corr_'));
      expect(result.approvalId, isNotEmpty);
      expect(AttendanceCorrectionStore.instance.listAll(), hasLength(1));
    });

    test('fails without submitAttendanceCorrection permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(submitAttendanceCorrectionProvider.notifier)
          .execute(
            const TeacherAttendanceCorrectionRequest(
              sisStudentId: 'stu_8a_01',
              studentName: 'Test',
              classLabel: '8',
              section: 'A',
              dateLabel: '12 Jun 2026',
              fromMark: 'Absent',
              toMark: 'Present',
              reason: 'Test',
            ),
          );

      expect(container.read(submitAttendanceCorrectionProvider).hasError, isTrue);
    });
  });
}
