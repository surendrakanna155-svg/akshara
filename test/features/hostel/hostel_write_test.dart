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

    test('createHostelRoom adds a vacant room to the catalog', () async {
      final repo = MockHostelRepository();
      final countBefore = (await repo.getRooms(query: query)).items.length;

      final room = await repo.createHostelRoom(
        query: query,
        request: const CreateHostelRoomRequest(
          block: 'D',
          roomNumber: '101',
          floor: 1,
          type: HostelRoomType.ac,
          totalBeds: 3,
          facilities: 'AC, study desk',
        ),
      );

      final roomsAfter = await repo.getRooms(query: query);
      expect(roomsAfter.items.length, countBefore + 1);
      expect(room.status, HostelRoomStatus.vacant);
      expect(room.occupiedBeds, 0);
      expect(room.totalBeds, 3);
      expect(roomsAfter.items.any((r) => r.id == room.id), isTrue);
    });

    test('createHostelRoom rejects a duplicate block + room number', () async {
      final repo = MockHostelRepository();
      final existing = (await repo.getRooms(query: query)).items.first;

      expect(
        () => repo.createHostelRoom(
          query: query,
          request: CreateHostelRoomRequest(
            block: existing.block,
            roomNumber: existing.roomNumber,
            floor: existing.floor,
            type: existing.type,
            totalBeds: existing.totalBeds,
            facilities: existing.facilities,
          ),
        ),
        throwsStateError,
      );
    });

    test('logVisitor adds an active visitor with an issued pass', () async {
      final repo = MockHostelRepository();
      final before = await repo.getVisitors(query: query);

      final visitor = await repo.logVisitor(
        query: query,
        request: const LogVisitorRequest(
          visitorName: 'Lakshmi Rao',
          relation: 'Mother',
          studentName: 'Ravi Kumar',
          sisStudentId: 'SIS-STU-10430',
        ),
      );

      final after = await repo.getVisitors(query: query);
      expect(after.activeVisitors.length, before.activeVisitors.length + 1);
      expect(visitor.status, HostelVisitorStatus.active);
      expect(visitor.checkOut, isNull);
      expect(visitor.passId, isNotEmpty);
      expect(after.activeVisitors.any((v) => v.id == visitor.id), isTrue);
    });

    test('logVisitor defaults a blank relation', () async {
      final repo = MockHostelRepository();

      final visitor = await repo.logVisitor(
        query: query,
        request: const LogVisitorRequest(
          visitorName: 'Unknown Guest',
          relation: '',
          studentName: 'Emma Thomas',
          sisStudentId: '',
        ),
      );

      expect(visitor.relation, '—');
    });

    test('logVisitor rejects an empty visitor name', () async {
      final repo = MockHostelRepository();

      expect(
        () => repo.logVisitor(
          query: query,
          request: const LogVisitorRequest(
            visitorName: '  ',
            relation: 'Father',
            studentName: 'Ravi Kumar',
            sisStudentId: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('recordHostelAttendance appends a roster row visible on read',
        () async {
      final repo = MockHostelRepository();
      final before = await repo.getAttendanceRecords(query: query);

      final record = await repo.recordHostelAttendance(
        query: query,
        request: const RecordHostelAttendanceRequest(
          studentName: 'Karthik Sharma',
          room: 'A-204',
          rollNumber: '8-A-09',
          morning: HostelAttendanceStatus.present,
          evening: HostelAttendanceStatus.absent,
          night: HostelAttendanceStatus.present,
          remark: 'Missed evening roll call',
          sisStudentId: 'SIS-STU-10425',
        ),
      );

      final after = await repo.getAttendanceRecords(query: query);
      expect(after.items.length, before.items.length + 1);
      // Worst-of-sessions decides overall (absent wins).
      expect(record.overallStatus, HostelAttendanceStatus.absent);
      expect(after.items.any((r) => r.id == record.id), isTrue);
    });

    test('recordHostelAttendance rejects an empty student name', () async {
      final repo = MockHostelRepository();

      expect(
        () => repo.recordHostelAttendance(
          query: query,
          request: const RecordHostelAttendanceRequest(
            studentName: '  ',
            room: 'A-204',
            rollNumber: '8-A-09',
            morning: HostelAttendanceStatus.present,
            evening: HostelAttendanceStatus.present,
            night: HostelAttendanceStatus.present,
            remark: '',
            sisStudentId: '',
          ),
        ),
        throwsStateError,
      );
    });

    test('recordMess appends a menu visible on the mess read', () async {
      final repo = MockHostelRepository();
      final before = await repo.getMessData(query: query);

      final menu = await repo.recordMess(
        query: query,
        request: const RecordMessRequest(
          day: 'Tue',
          mealType: HostelMealType.dinner,
          items: 'Roti · Paneer · Curd',
          dietaryTags: ['Veg'],
          headcount: 120,
          costRupees: 60000,
        ),
      );

      final after = await repo.getMessData(query: query);
      expect(after.weeklyMenus.length, before.weeklyMenus.length + 1);
      expect(menu.day, 'Tue');
      expect(
        after.weeklyMenus.any((m) => m.day == 'Tue' && m.items == menu.items),
        isTrue,
      );
    });

    test('recordMess rejects a negative cost', () async {
      final repo = MockHostelRepository();

      expect(
        () => repo.recordMess(
          query: query,
          request: const RecordMessRequest(
            day: 'Wed',
            mealType: HostelMealType.lunch,
            items: 'Rice · Dal',
            dietaryTags: [],
            headcount: 100,
            costRupees: -1,
          ),
        ),
        throwsStateError,
      );
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

    test('createHostelRoom fails without manageHostel', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createHostelRoomProvider.notifier).execute(
            const CreateHostelRoomRequest(
              block: 'D',
              roomNumber: '102',
              floor: 1,
              type: HostelRoomType.standard,
              totalBeds: 2,
              facilities: 'Study desk',
            ),
          );

      expect(container.read(createHostelRoomProvider).hasError, isTrue);
    });

    test('createHostelRoom succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createHostelRoomProvider.notifier).execute(
            const CreateHostelRoomRequest(
              block: 'D',
              roomNumber: '103',
              floor: 1,
              type: HostelRoomType.standard,
              totalBeds: 2,
              facilities: 'Study desk',
            ),
          );

      expect(container.read(createHostelRoomProvider).hasValue, isTrue);
      expect(
        container.read(createHostelRoomProvider).value?.status,
        HostelRoomStatus.vacant,
      );
    });

    test('logVisitor fails without manageHostel', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(logVisitorProvider.notifier).execute(
            const LogVisitorRequest(
              visitorName: 'Blocked Visitor',
              relation: 'Father',
              studentName: 'Ravi Kumar',
              sisStudentId: '',
            ),
          );

      expect(container.read(logVisitorProvider).hasError, isTrue);
    });

    test('logVisitor succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(logVisitorProvider.notifier).execute(
            const LogVisitorRequest(
              visitorName: 'Allowed Visitor',
              relation: 'Mother',
              studentName: 'Emma Thomas',
              sisStudentId: 'SIS-STU-10418',
            ),
          );

      expect(container.read(logVisitorProvider).hasValue, isTrue);
      expect(
        container.read(logVisitorProvider).value?.status,
        HostelVisitorStatus.active,
      );
    });

    test('recordHostelAttendance fails without manageHostel', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordHostelAttendanceProvider.notifier).execute(
            const RecordHostelAttendanceRequest(
              studentName: 'Ravi Kumar',
              room: 'A-204',
              rollNumber: '10-A-12',
              morning: HostelAttendanceStatus.present,
              evening: HostelAttendanceStatus.present,
              night: HostelAttendanceStatus.present,
              remark: '',
              sisStudentId: 'SIS-STU-10430',
            ),
          );

      expect(container.read(recordHostelAttendanceProvider).hasError, isTrue);
    });

    test('recordHostelAttendance succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordHostelAttendanceProvider.notifier).execute(
            const RecordHostelAttendanceRequest(
              studentName: 'Ravi Kumar',
              room: 'A-204',
              rollNumber: '10-A-12',
              morning: HostelAttendanceStatus.present,
              evening: HostelAttendanceStatus.onLeave,
              night: HostelAttendanceStatus.present,
              remark: '',
              sisStudentId: 'SIS-STU-10430',
            ),
          );

      expect(container.read(recordHostelAttendanceProvider).hasValue, isTrue);
      expect(
        container.read(recordHostelAttendanceProvider).value?.overallStatus,
        HostelAttendanceStatus.onLeave,
      );
    });

    test('recordMess fails without manageHostel', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordMessProvider.notifier).execute(
            const RecordMessRequest(
              day: 'Mon',
              mealType: HostelMealType.lunch,
              items: 'Rice · Dal',
              dietaryTags: ['Veg'],
              headcount: 100,
              costRupees: 40000,
            ),
          );

      expect(container.read(recordMessProvider).hasError, isTrue);
    });

    test('recordMess succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(recordMessProvider.notifier).execute(
            const RecordMessRequest(
              day: 'Mon',
              mealType: HostelMealType.lunch,
              items: 'Rice · Dal',
              dietaryTags: ['Veg'],
              headcount: 100,
              costRupees: 40000,
            ),
          );

      expect(container.read(recordMessProvider).hasValue, isTrue);
      expect(container.read(recordMessProvider).value?.day, 'Mon');
    });
  });
}
