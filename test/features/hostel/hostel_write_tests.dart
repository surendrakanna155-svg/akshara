import 'package:akshara_erp/core/repositories/mock/mock_hostel_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/hostel/hostel_models.dart';
import 'package:akshara_erp/features/hostel/hostel_mutations_provider.dart';
import 'package:akshara_erp/features/hostel/hostel_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Hostel mock writes', () {
    const query = RepositoryQuery.demo;

    test('admitHostelStudent creates awaiting allocation record', () async {
      final repo = MockHostelRepository();

      final student = await repo.admitHostelStudent(
        query: query,
        request: const AdmitHostelStudentRequest(
          sisStudentId: 'SIS-STU-99999',
          studentName: 'QA Hostel Student',
          admissionNumber: 'ADM-2026-9999',
          classLabel: '9',
        ),
      );

      expect(student.status, HostelStudentStatus.awaitingAllocation);
      expect(student.room, '—');
    });

    test('assignHostelRoom updates room capacity and student status', () async {
      final repo = MockHostelRepository();
      final roomsBefore = await repo.getRooms(query: query);
      final vacantRoom = roomsBefore.items.firstWhere((r) => r.id == 'room_4');
      expect(vacantRoom.occupiedBeds, 0);

      final assigned = await repo.assignHostelRoom(
        query: query,
        request: const AssignHostelRoomRequest(
          hostelStudentId: 'ho_stu_5',
          roomId: 'room_4',
          bed: 'B1',
        ),
      );

      final roomsAfter = await repo.getRooms(query: query);
      final updatedRoom = roomsAfter.items.firstWhere((r) => r.id == 'room_4');

      expect(assigned.status, HostelStudentStatus.resident);
      expect(assigned.room, 'B-401');
      expect(updatedRoom.occupiedBeds, 1);
    });

    test('checkoutHostelStudent restores room availability', () async {
      final repo = MockHostelRepository();
      final roomsBefore = await repo.getRooms(query: query);
      final room = roomsBefore.items.firstWhere((r) => r.id == 'room_2');
      final occupiedBefore = room.occupiedBeds;

      final checkedOut = await repo.checkoutHostelStudent(
        query: query,
        request: const CheckoutHostelStudentRequest(hostelStudentId: 'ho_stu_2'),
      );

      final roomsAfter = await repo.getRooms(query: query);
      final updatedRoom = roomsAfter.items.firstWhere((r) => r.id == 'room_2');

      expect(checkedOut.status, HostelStudentStatus.checkedOut);
      expect(updatedRoom.occupiedBeds, occupiedBefore - 1);
    });

    test('assignHostelRoom supports room transfer', () async {
      final repo = MockHostelRepository();

      await repo.assignHostelRoom(
        query: query,
        request: const AssignHostelRoomRequest(
          hostelStudentId: 'ho_stu_1',
          roomId: 'room_4',
          bed: 'B2',
        ),
      );

      final student = (await repo.getStudents(query: query))
          .items
          .firstWhere((s) => s.id == 'ho_stu_1');
      expect(student.room, 'B-401');
    });
  });

  group('Hostel RBAC mutations', () {
    test('assignHostelRoom fails without manageHostel', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(assignHostelRoomProvider.notifier).execute(
            const AssignHostelRoomRequest(
              hostelStudentId: 'ho_stu_5',
              roomId: 'room_4',
              bed: 'B1',
            ),
          );

      expect(container.read(assignHostelRoomProvider).hasError, isTrue);
    });

    test('checkoutHostelStudent succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(checkoutHostelStudentProvider.notifier).execute(
            const CheckoutHostelStudentRequest(hostelStudentId: 'ho_stu_4'),
          );

      expect(container.read(checkoutHostelStudentProvider).hasValue, isTrue);
      expect(
        container.read(checkoutHostelStudentProvider).value?.status,
        HostelStudentStatus.checkedOut,
      );
    });
  });
}
