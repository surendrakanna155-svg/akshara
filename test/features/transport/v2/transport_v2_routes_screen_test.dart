import 'package:akshara_erp/core/repositories/api/transport/v2/transport_v2_repository.dart';
import 'package:akshara_erp/features/admin/admin_filter_bar.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/transport/v2/routes/transport_v2_routes_screen.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_models.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_providers.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// BUS-033/034/035/042 — Transport v2 Routes screen · ADMIN hop.
///
/// This is the Transport-Admin leg of the roadmap's five-hop completion rule.
/// The Driver, Parent and Student legs are pinned separately (they need Phase 7
/// and BUS-095/096/101 respectively), so these tests do NOT by themselves
/// promote the tasks to Verified — see the roadmap status note.
///
/// What they prove an admin can now do, none of which was possible before:
///   * edit a route at all (BUS-033)
///   * retire or delete one (BUS-034)
///   * see WHY a route cannot be activated (BUS-042)
///   * tell today's substitute from the permanent arrangement (BUS-051)
///   * tell cached data from live data
TransportRouteV2 _route({
  String id = 'r1',
  String name = 'Route 12 — North',
  RouteV2Status status = RouteV2Status.draft,
  Map<String, dynamic>? assignment,
  List<Map<String, dynamic>> stops = const [],
  int studentCount = 0,
}) {
  return TransportRouteV2.fromJson({
    'id': id,
    'name': name,
    'shift': 'am',
    'direction': 'pickup',
    'status': switch (status) {
      RouteV2Status.active => 'active',
      RouteV2Status.draft => 'draft',
      RouteV2Status.inactive => 'inactive',
    },
    'studentCount': studentCount,
    'stops': stops,
    if (assignment != null) 'assignment': assignment,
  });
}

/// A desktop-sized surface. The transport module scaffold renders its filter bar
/// and action row differently on narrow widths, and these tests assert on both,
/// so the width is pinned rather than inherited from the default mobile helper.
void _useWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required List<TransportRouteV2> routes,
  bool enabled = true,
  bool isStale = false,
  DateTime? cachedAt,
  List<UnstaffedRouteV2> unstaffed = const [],
  RouteReadinessV2? readiness,
}) async {
  _useWideViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        transportV2EnabledProvider.overrideWithValue(enabled),
        transportV2RoutesProvider.overrideWith((ref) async => RoutesResult(
              routes: routes,
              isStale: isStale,
              cachedAt: cachedAt,
            )),
        transportV2UnstaffedProvider.overrideWith((ref) async => unstaffed),
        if (readiness != null)
          transportV2ReadinessProvider('r1').overrideWith((ref) async => readiness),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: TransportV2RoutesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BUS-015 · per-school gating', () {
    testWidgets('an unmigrated school sees an explanation, not an error',
        (tester) async {
      await _pump(tester, routes: const [], enabled: false);
      expect(find.byKey(QaTestKeys.transportV2NotEnabledState), findsOneWidget);
      // Not-enabled is not a failure: no error copy, no retry.
      expect(find.textContaining('Unable to load'), findsNothing);
    });
  });

  group('BUS-033/035 · route editing exists at all', () {
    testWidgets('every route offers an Edit action', (tester) async {
      await _pump(tester, routes: [_route()]);
      // Pre-v2 there was no update endpoint, so no edit affordance could exist.
      expect(find.byKey(QaTestKeys.transportV2EditRouteButton('r1')),
          findsOneWidget);
    });

    testWidgets('the create form exposes every persisted field', (tester) async {
      await _pump(tester, routes: const []);
      await tester.tap(find.byKey(QaTestKeys.transportV2CreateRouteButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2RouteFormDialog), findsOneWidget);
      // The legacy dialog had ONE field and silently hardcoded these four.
      expect(find.byKey(QaTestKeys.transportV2RouteNameField), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2RouteShiftField), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2RouteDirectionField), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2RouteDepartureField), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2RouteReturnField), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2RouteDistanceField), findsOneWidget);
    });

    testWidgets('a blank name is rejected in-form, not silently accepted',
        (tester) async {
      await _pump(tester, routes: const []);
      await tester.tap(find.byKey(QaTestKeys.transportV2CreateRouteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.transportV2RouteFormSubmitButton));
      await tester.pumpAndSettle();

      expect(find.text('Route name is required'), findsOneWidget);
      // The dialog stays open so the admin can fix it.
      expect(find.byKey(QaTestKeys.transportV2RouteFormDialog), findsOneWidget);
    });

    testWidgets('the edit form prefills from the persisted route', (tester) async {
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'Route 12 — North',
        'code': 'R12',
        'shift': 'pm',
        'status': 'draft',
        'defaultDepartureTime': '07:05',
        'defaultReturnTime': '15:40',
        'distanceM': 14200,
      });
      await _pump(tester, routes: [route]);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditRouteButton('r1')));
      await tester.pumpAndSettle();

      // BUS-007's lesson: a form must load what it will submit, or it erases it.
      expect(find.text('Route 12 — North'), findsWidgets);
      expect(find.text('R12'), findsOneWidget);
      expect(find.textContaining('7:05 AM'), findsOneWidget);
      expect(find.textContaining('3:40 PM'), findsOneWidget);
      expect(find.text('14.2'), findsOneWidget);
    });

    testWidgets('an unset time reads "Not set", never a fabricated default',
        (tester) async {
      await _pump(tester, routes: [_route()]);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditRouteButton('r1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not set'), findsWidgets);
    });
  });

  group('BUS-034 · retire and delete', () {
    testWidgets('an active route offers Deactivate, not only Activate',
        (tester) async {
      await _pump(tester, routes: [_route(status: RouteV2Status.active)]);
      expect(find.byKey(QaTestKeys.transportV2DeactivateRouteButton('r1')),
          findsOneWidget);
      // Activate is hidden for an already-active route.
      expect(find.byKey(QaTestKeys.transportV2ActivateRouteButton('r1')),
          findsNothing);
    });

    testWidgets('a draft route offers Activate', (tester) async {
      await _pump(tester, routes: [_route()]);
      expect(find.byKey(QaTestKeys.transportV2ActivateRouteButton('r1')),
          findsOneWidget);
    });

    testWidgets('delete requires confirmation and warns about history',
        (tester) async {
      await _pump(tester, routes: [_route()]);
      await tester.tap(find.byKey(QaTestKeys.transportV2DeleteRouteButton('r1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.textContaining('deactivate it instead'), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2DeleteRouteConfirmButton),
          findsOneWidget);
    });
  });

  group('BUS-042 · the publish gate is visible', () {
    testWidgets('readiness lists what is missing, as actions', (tester) async {
      await _pump(
        tester,
        routes: [_route()],
        readiness: RouteReadinessV2.fromJson({
          'ready': false,
          'blockers': [
            'stops_missing_location',
            'no_vehicle_assigned',
            'no_driver_assigned',
          ],
        }),
      );
      await tester.tap(find.byKey(QaTestKeys.transportV2ReadinessButton('r1')));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2ReadinessDialog), findsOneWidget);
      // Each blocker is phrased as the action to take. The legacy activate
      // endpoint accepted anything and displayed nothing.
      expect(find.text('Assign a bus'), findsOneWidget);
      expect(find.text('Assign a driver'), findsOneWidget);
      expect(find.textContaining('Place every stop on the map'), findsOneWidget);
    });

    testWidgets('a ready route says so', (tester) async {
      await _pump(
        tester,
        routes: [_route()],
        readiness: RouteReadinessV2.fromJson({'ready': true, 'blockers': []}),
      );
      await tester.tap(find.byKey(QaTestKeys.transportV2ReadinessButton('r1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ready to activate'), findsOneWidget);
    });

    testWidgets('a route with unlocated stops warns on the card itself',
        (tester) async {
      await _pump(tester, routes: [
        _route(stops: [
          {'id': 's1', 'name': 'Migrated', 'sequence': 1, 'status': 'needs_location'},
        ]),
      ]);
      // The gap must be visible without opening a dialog — BUS-030's migration
      // debt has to be loud.
      expect(find.textContaining('have no location'), findsOneWidget);
    });

    testWidgets('out-of-order stop times are surfaced as a warning',
        (tester) async {
      await _pump(tester, routes: [
        _route(stops: [
          {'id': 's1', 'name': 'A', 'sequence': 1, 'pickupTime': '07:30',
           'latitude': 17.44, 'longitude': 78.39},
          {'id': 's2', 'name': 'B', 'sequence': 2, 'pickupTime': '07:05',
           'latitude': 17.45, 'longitude': 78.40},
        ]),
      ]);
      // Only detectable because BUS-038 made times comparable.
      expect(find.textContaining('do not run in order'), findsOneWidget);
    });
  });

  group('BUS-043/051 · assignment is visible and dated', () {
    testWidgets('an unassigned route says so explicitly', (tester) async {
      await _pump(tester, routes: [_route()]);
      // Pre-v2 this rendered as an empty string — indistinguishable from
      // "not loaded", which is why three features died unnoticed.
      expect(find.textContaining('Not assigned yet'), findsOneWidget);
    });

    testWidgets('an assigned route shows the bus and driver', (tester) async {
      await _pump(tester, routes: [
        _route(assignment: {
          'assignmentId': 'a1',
          'vehicleId': 'v1',
          'vehicleRegistration': 'TS 09 AB 4521',
          'driverId': 'd1',
          'driverName': 'Ramesh Kumar',
          'assignmentKind': 'permanent',
          'effectiveFrom': '2026-07-01',
        }),
      ]);
      expect(find.textContaining('TS 09 AB 4521'), findsOneWidget);
      expect(find.textContaining('Ramesh Kumar'), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2SubstituteChip('r1')), findsNothing);
    });

    testWidgets('a substitute is LABELLED so today differs visibly from normal',
        (tester) async {
      await _pump(tester, routes: [
        _route(assignment: {
          'assignmentId': 'a2',
          'driverId': 'd2',
          'driverName': 'Suresh Naidu',
          'assignmentKind': 'substitute',
          'effectiveFrom': '2026-07-30',
          'effectiveTo': '2026-07-30',
          'reason': 'Ramesh on sick leave',
        }),
      ]);
      expect(find.byKey(QaTestKeys.transportV2SubstituteChip('r1')), findsOneWidget);
      expect(find.textContaining('Suresh Naidu'), findsOneWidget);
    });
  });

  group('BUS-050 · unstaffed routes are surfaced before the bus fails to arrive',
      () {
    testWidgets('the banner names each route and WHY', (tester) async {
      await _pump(tester, routes: [_route()], unstaffed: [
        UnstaffedRouteV2.fromJson(
            {'routeId': 'r1', 'routeName': 'Route 12', 'missing': 'driver_unavailable'}),
        UnstaffedRouteV2.fromJson(
            {'routeId': 'r2', 'routeName': 'Route 08', 'missing': 'no_vehicle'}),
      ]);
      expect(find.byKey(QaTestKeys.transportV2UnstaffedBanner), findsOneWidget);
      expect(find.textContaining('2 routes need attention'), findsOneWidget);
      expect(find.textContaining('assign a substitute'), findsOneWidget);
      expect(find.textContaining('No bus assigned'), findsOneWidget);
    });

    testWidgets('no banner when every route is staffed', (tester) async {
      await _pump(tester, routes: [_route()], unstaffed: const []);
      expect(find.byKey(QaTestKeys.transportV2UnstaffedBanner), findsNothing);
    });
  });

  group('Offline disclosure · cached data is never shown as live', () {
    testWidgets('a stale read is banner-flagged with its age', (tester) async {
      await _pump(
        tester,
        routes: [_route()],
        isStale: true,
        cachedAt: DateTime(2026, 7, 30, 6, 45),
      );
      expect(find.byKey(QaTestKeys.transportV2StaleBanner), findsOneWidget);
      expect(find.textContaining('Showing saved data from 06:45'), findsOneWidget);
    });

    testWidgets('a live read shows no banner', (tester) async {
      await _pump(tester, routes: [_route()]);
      expect(find.byKey(QaTestKeys.transportV2StaleBanner), findsNothing);
    });
  });

  group('Filters', () {
    testWidgets('status filters narrow the list', (tester) async {
      await _pump(tester, routes: [
        _route(id: 'r1', name: 'Active one', status: RouteV2Status.active),
        _route(id: 'r2', name: 'Draft one'),
      ]);
      expect(find.byKey(QaTestKeys.transportV2RouteCard('r1')), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2RouteCard('r2')), findsOneWidget);

      // "Draft" appears BOTH as a filter label and as a route's status chip, so
      // the tap must be scoped to the filter bar. A bare find.text would be
      // ambiguous — and would silently start tapping the wrong widget if the
      // chip label ever changed.
      await tester.tap(
        find.descendant(
          of: find.byType(AdminFilterBar),
          matching: find.text('Draft'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(QaTestKeys.transportV2RouteCard('r1')), findsNothing);
      expect(find.byKey(QaTestKeys.transportV2RouteCard('r2')), findsOneWidget);
    });
  });
}
