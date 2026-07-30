import 'package:akshara_erp/core/repositories/api/transport/v2/transport_v2_repository.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/transport/v2/routes/transport_v2_routes_screen.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_models.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_providers.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// BUS-043/044/046/048/050/051/054 — assignment & substitution · ADMIN hop.
///
/// This covers the operation that simply did not exist pre-v2: putting a bus and
/// a driver on a route. Its absence silently disabled the capacity guard and both
/// in-use delete guards, and made the owner's substitute-driver requirement
/// unrepresentable.
///
/// The picker tests carry the most weight. An admin who is offered a driver who
/// is on leave will "arrange cover" and still have nobody to drive — so the
/// pickers must state ineligibility inline rather than failing on submit.
TransportRouteV2 _route({Map<String, dynamic>? assignment}) =>
    TransportRouteV2.fromJson({
      'id': 'r1',
      'name': 'Route 12 — North',
      'shift': 'am',
      'status': 'draft',
      if (assignment != null) 'assignment': assignment,
    });

VehicleV2 _vehicle({
  String id = 'v1',
  String reg = 'TS 09 AB 4521',
  int capacity = 48,
  String? expired,
  String? onRoute,
  String status = 'active',
}) =>
    VehicleV2.fromJson({
      'id': id,
      'registration': reg,
      'model': 'Tata',
      'capacity': capacity,
      'status': status,
      if (expired != null) 'expiredDocument': expired,
      if (onRoute != null) 'assignedRouteName': onRoute,
    });

DriverV2 _driver({
  String id = 'd1',
  String name = 'Ramesh Kumar',
  bool licenceExpired = false,
  String? unavailable,
  String? onRoute,
}) =>
    DriverV2.fromJson({
      'id': id,
      'name': name,
      'licenceNumber': 'DL-1',
      'licenceExpired': licenceExpired,
      if (unavailable != null) 'unavailableKind': unavailable,
      if (onRoute != null) 'assignedRouteName': onRoute,
    });

void _useWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  TransportRouteV2? route,
  List<VehicleV2> vehicles = const [],
  List<DriverV2> drivers = const [],
}) async {
  _useWideViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        transportV2EnabledProvider.overrideWithValue(true),
        transportV2RoutesProvider.overrideWith((ref) async => RoutesResult(
              routes: [route ?? _route()],
              isStale: false,
              cachedAt: null,
            )),
        transportV2UnstaffedProvider.overrideWith((ref) async => const []),
        transportV2VehiclesProvider.overrideWith((ref) async => vehicles),
        transportV2DriversProvider.overrideWith((ref) async => drivers),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: TransportV2RoutesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAssign(WidgetTester tester, {bool substitute = false}) async {
  await tester.tap(find.byKey(substitute
      ? QaTestKeys.transportV2SubstituteButton('r1')
      : QaTestKeys.transportV2AssignButton('r1')));
  await tester.pumpAndSettle();
}

/// Opens a picker's menu.
///
/// A COLLAPSED DropdownButtonFormField renders only the SELECTED option, so the
/// per-option blocker text ("insurance expired", "on leave") is not in the tree
/// until the menu is open. Asserting on it while collapsed would pass only by
/// accident on whichever option happened to be selected.
Future<void> _openPicker(WidgetTester tester, Key pickerKey) async {
  await tester.tap(find.byKey(pickerKey));
  await tester.pumpAndSettle();
}

void main() {
  group('BUS-043/048 · the assign action exists at all', () {
    testWidgets('an unassigned route offers "Assign"', (tester) async {
      await _pump(tester);
      // Pre-v2 no endpoint wrote assignedBus, so no such affordance could exist.
      expect(find.byKey(QaTestKeys.transportV2AssignButton('r1')), findsOneWidget);
      expect(find.text('Assign'), findsOneWidget);
    });

    testWidgets('an assigned route offers "Reassign"', (tester) async {
      await _pump(
        tester,
        route: _route(assignment: {
          'assignmentId': 'a1',
          'vehicleId': 'v1',
          'vehicleRegistration': 'TS 09 AB 4521',
          'driverId': 'd1',
          'driverName': 'Ramesh Kumar',
          'assignmentKind': 'permanent',
          'effectiveFrom': '2026-07-01',
        }),
      );
      expect(find.text('Reassign'), findsOneWidget);
    });

    testWidgets('the dialog prefills the assignment in force', (tester) async {
      await _pump(
        tester,
        route: _route(assignment: {
          'assignmentId': 'a1',
          'vehicleId': 'v1',
          'driverId': 'd1',
          'assignmentKind': 'permanent',
          'effectiveFrom': '2026-07-01',
        }),
        vehicles: [_vehicle()],
        drivers: [_driver()],
      );
      await _openAssign(tester);
      // Prefill matters: a driver-only change must not silently drop the bus.
      expect(find.textContaining('TS 09 AB 4521'), findsWidgets);
      expect(find.textContaining('Ramesh Kumar'), findsWidgets);
    });

    testWidgets('assigning neither a bus nor a driver is refused', (tester) async {
      await _pump(tester, vehicles: [_vehicle()], drivers: [_driver()]);
      await _openAssign(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2AssignmentSubmitButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2AssignmentError), findsOneWidget);
      expect(find.textContaining('Choose a bus or a driver'), findsOneWidget);
    });
  });

  group('BUS-054 · pickers state ineligibility INLINE', () {
    testWidgets('a bus with expired insurance says so in the option',
        (tester) async {
      await _pump(tester, vehicles: [_vehicle(expired: 'insurance')]);
      await _openAssign(tester);
      await _openPicker(tester, QaTestKeys.transportV2AssignVehicleField);
      // Offering it and failing only on submit teaches admins to ignore errors.
      expect(find.textContaining('insurance expired'), findsWidgets);
    });

    testWidgets('a driver with an expired licence says so', (tester) async {
      await _pump(tester, drivers: [_driver(licenceExpired: true)]);
      await _openAssign(tester);
      await _openPicker(tester, QaTestKeys.transportV2AssignDriverField);
      expect(find.textContaining('licence expired'), findsWidgets);
    });

    testWidgets('a driver on leave says so — the one that matters most',
        (tester) async {
      await _pump(tester, drivers: [_driver(unavailable: 'leave')]);
      await _openAssign(tester);
      await _openPicker(tester, QaTestKeys.transportV2AssignDriverField);
      // Picking an unavailable driver is how a school "arranges cover" and still
      // has nobody to drive (BUS-050).
      expect(find.textContaining('on leave'), findsWidgets);
    });

    testWidgets('an already-committed bus names the route it runs',
        (tester) async {
      await _pump(tester, vehicles: [_vehicle(onRoute: 'Route 08 — West')]);
      await _openAssign(tester);
      await _openPicker(tester, QaTestKeys.transportV2AssignVehicleField);
      expect(find.textContaining('already on Route 08 — West'), findsWidgets);
    });

    testWidgets('a compliant, free option carries no blocker text',
        (tester) async {
      await _pump(tester, vehicles: [_vehicle()], drivers: [_driver()]);
      await _openAssign(tester);
      // Opened, or this would pass vacuously on a collapsed picker.
      await _openPicker(tester, QaTestKeys.transportV2AssignVehicleField);
      expect(find.textContaining('expired'), findsNothing);
      expect(find.textContaining('already on'), findsNothing);
    });

    testWidgets('the compliance override is NOT offered pre-emptively',
        (tester) async {
      await _pump(tester, vehicles: [_vehicle(expired: 'insurance')]);
      await _openAssign(tester);
      // It appears only after the gate actually refuses, so it cannot be ticked
      // out of habit before anyone has been told there is a problem.
      expect(find.byKey(QaTestKeys.transportV2AllowNonCompliantCheckbox),
          findsNothing);
    });
  });

  group('BUS-051 · substitution leaves the permanent arrangement alone', () {
    testWidgets('the substitute action exists on every route', (tester) async {
      await _pump(tester);
      expect(find.byKey(QaTestKeys.transportV2SubstituteButton('r1')),
          findsOneWidget);
    });

    testWidgets('the sheet states that the permanent arrangement is untouched',
        (tester) async {
      await _pump(tester, drivers: [_driver()]);
      await _openAssign(tester, substitute: true);

      expect(find.byKey(QaTestKeys.transportV2SubstituteExplainer), findsOneWidget);
      // This is the owner's requirement in one sentence — the admin must be able
      // to trust that tomorrow reverts without any cleanup step.
      expect(find.textContaining('resumes automatically'), findsOneWidget);
    });

    testWidgets('a substitution offers a bounded date range', (tester) async {
      await _pump(tester, drivers: [_driver()]);
      await _openAssign(tester, substitute: true);
      expect(find.byKey(QaTestKeys.transportV2SubstituteFromField), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2SubstituteToField), findsOneWidget);
    });

    testWidgets('a substitution REQUIRES a reason', (tester) async {
      await _pump(tester, drivers: [_driver(id: 'd2', name: 'Suresh Naidu')]);
      await _openAssign(tester, substitute: true);

      // Pick the driver, leave the reason blank.
      await tester.tap(find.byKey(QaTestKeys.transportV2AssignDriverField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suresh Naidu').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.transportV2AssignmentSubmitButton));
      await tester.pumpAndSettle();

      // An unexplained substitution is an unauditable one.
      expect(find.textContaining('reason is required'), findsOneWidget);
    });

    testWidgets('a permanent assignment does NOT demand a reason',
        (tester) async {
      await _pump(tester, drivers: [_driver(id: 'd2', name: 'Suresh Naidu')]);
      await _openAssign(tester);
      expect(find.byKey(QaTestKeys.transportV2SubstituteExplainer), findsNothing);
      // The reason field is present but optional for the standing arrangement.
      expect(find.textContaining('Note (optional)'), findsOneWidget);
    });
  });

  group('Model semantics the pickers depend on', () {
    test('VehicleV2 blocker precedence puts the document first', () {
      expect(_vehicle(expired: 'fitness').blockerLabel, 'fitness expired');
      expect(_vehicle(status: 'maintenance').blockerLabel, 'maintenance');
      expect(_vehicle().blockerLabel, isNull);
      expect(_vehicle().isCompliant, isTrue);
      expect(_vehicle(expired: 'permit').isCompliant, isFalse);
    });

    test('DriverV2.isAssignable is false for leave OR expired licence', () {
      expect(_driver().isAssignable, isTrue);
      expect(_driver(licenceExpired: true).isAssignable, isFalse);
      expect(_driver(unavailable: 'sick').isAssignable, isFalse);
      // Committed is NOT the same as unassignable — an admin may deliberately
      // move a bus between routes.
      expect(_driver(onRoute: 'Route 08').isAssignable, isTrue);
      expect(_driver(onRoute: 'Route 08').isCommitted, isTrue);
    });

    test('DriverV2 blocker names the leave kind', () {
      expect(_driver(unavailable: 'sick').blockerLabel, 'on sick');
      expect(_driver(licenceExpired: true).blockerLabel, 'licence expired');
    });
  });
}
