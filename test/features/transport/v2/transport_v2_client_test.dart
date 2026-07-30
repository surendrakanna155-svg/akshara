import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/repositories/api/transport/v2/transport_v2_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/transport/v2/transport_v2_datasource.dart';
import 'package:akshara_erp/core/repositories/api/transport/v2/transport_v2_repository.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_models.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transport v2 CLIENT LAYER — models, paths, error semantics, offline policy.
///
/// WHY THESE TESTS EXIST
///
/// The v2 client is a clean-room replacement for a layer whose defects the audit
/// catalogued: coordinates that defaulted to (0, 0), free-text stop times that
/// could not be compared, a vehicle referenced by a mutable string, frozen
/// display copies that went stale, and a write path that silently substituted a
/// mock and reported success.
///
/// These tests pin the properties that make those defects UNREPRESENTABLE in the
/// new types, rather than merely absent from the current code.
void main() {
  group('GeoPoint — coordinates cannot be invalid', () {
    test('accepts a real coordinate', () {
      final p = GeoPoint.tryParse(17.4484, 78.3908);
      expect(p, isNotNull);
      expect(p!.latitude, 17.4484);
      expect(p.longitude, 78.3908);
    });

    test('rejects NULL ISLAND (0,0) — the legacy default for every stop', () {
      // The pre-v2 write path dropped coordinates and the mapper defaulted them
      // to 0, putting every stop in the Atlantic off Ghana. That value must not
      // be constructible.
      expect(GeoPoint.tryParse(0, 0), isNull);
      expect(GeoPoint.tryParse(0.00001, -0.00002), isNull);
    });

    test('rejects out-of-range and non-finite values', () {
      expect(GeoPoint.tryParse(91, 0), isNull);
      expect(GeoPoint.tryParse(-91, 0), isNull);
      expect(GeoPoint.tryParse(0, 181), isNull);
      expect(GeoPoint.tryParse(0, -181), isNull);
      expect(GeoPoint.tryParse(double.nan, 10), isNull);
    });

    test('rejects a missing half of the pair rather than defaulting it', () {
      expect(GeoPoint.tryParse(17.4, null), isNull);
      expect(GeoPoint.tryParse(null, 78.3), isNull);
    });

    test('a legitimate coordinate near the equator still works', () {
      // The (0,0) guard must not reject genuine near-equatorial locations.
      expect(GeoPoint.tryParse(1.2921, 36.8219), isNotNull); // Nairobi
    });
  });

  group('StopTime — times are arithmetic, not text', () {
    test('parses the canonical HH:MM wire format', () {
      expect(StopTime.tryParse('07:05')!.minutesFromMidnight, 7 * 60 + 5);
      expect(StopTime.tryParse('15:40')!.minutesFromMidnight, 15 * 60 + 40);
      expect(StopTime.tryParse('00:00')!.minutesFromMidnight, 0);
    });

    test('rejects the free-text junk the legacy field accepted', () {
      // Every one of these persisted unvalidated pre-v2, which is exactly why
      // schedule adherence and ETA were impossible to compute.
      for (final junk in ['7.05', '0705', 'morning', '7', '25:00', '12:60', '']) {
        expect(StopTime.tryParse(junk), isNull, reason: '"$junk" must be rejected');
      }
    });

    test('is comparable and subtractable — the property text lacked', () {
      final a = StopTime.tryParse('07:05')!;
      final b = StopTime.tryParse('07:18')!;
      expect(a.compareTo(b), lessThan(0));
      expect(b.minutesFromMidnight - a.minutesFromMidnight, 13);
    });

    test('round-trips through the wire format', () {
      for (final wire in ['00:00', '07:05', '12:00', '15:40', '23:59']) {
        expect(StopTime.tryParse(wire)!.toWire(), wire);
      }
    });

    test('displays 12-hour with correct midnight and noon', () {
      expect(StopTime.tryParse('00:30')!.toDisplay(), '12:30 AM');
      expect(StopTime.tryParse('12:30')!.toDisplay(), '12:30 PM');
      expect(StopTime.tryParse('07:05')!.toDisplay(), '7:05 AM');
      expect(StopTime.tryParse('15:40')!.toDisplay(), '3:40 PM');
    });
  });

  group('TransportRouteV2 — the template carries no operational scalar', () {
    test('parses a route with its stops ordered by sequence', () {
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'Route 12 — North',
        'shift': 'am',
        'status': 'active',
        'stops': [
          {'id': 's2', 'name': 'Second', 'sequence': 2, 'latitude': 17.45, 'longitude': 78.40},
          {'id': 's1', 'name': 'First', 'sequence': 1, 'latitude': 17.44, 'longitude': 78.39},
        ],
      });
      expect(route.stopCount, 2);
      // Order comes from `sequence`, never from array position.
      expect(route.stops.first.stop.name, 'First');
      expect(route.stops.last.stop.name, 'Second');
    });

    test('an unstaffed route has a NULL assignment, not an empty string', () {
      final route = TransportRouteV2.fromJson({'id': 'r1', 'name': 'R'});
      // Pre-v2 this was `assignedBus: ""` — indistinguishable from "not yet
      // loaded" and the reason three features silently died.
      expect(route.assignment, isNull);
    });

    test('an assigned route exposes the vehicle via the assignment', () {
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'assignment': {
          'assignmentId': 'a1',
          'vehicleId': 'v1',
          'vehicleRegistration': 'TS 09 AB 4521',
          'driverId': 'd1',
          'driverName': 'Ramesh Kumar',
          'assignmentKind': 'permanent',
          'effectiveFrom': '2026-07-01',
        },
      });
      expect(route.assignment!.hasVehicle, isTrue);
      expect(route.assignment!.hasDriver, isTrue);
      expect(route.assignment!.isSubstitute, isFalse);
      expect(route.assignment!.vehicleRegistration, 'TS 09 AB 4521');
    });

    test('a substitute assignment is flagged so the UI can say so', () {
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'assignment': {
          'assignmentId': 'a2',
          'driverId': 'd2',
          'driverName': 'Suresh Naidu',
          'assignmentKind': 'substitute',
          'effectiveFrom': '2026-07-30',
          'effectiveTo': '2026-07-30',
          'reason': 'Ramesh on sick leave',
        },
      });
      // A driver covering an unfamiliar route must be TOLD they are substituting.
      expect(route.assignment!.isSubstitute, isTrue);
      expect(route.assignment!.reason, 'Ramesh on sick leave');
    });

    test('surfaces stops still missing a location (blocks publication)', () {
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'stops': [
          {'id': 's1', 'name': 'Located', 'sequence': 1, 'latitude': 17.44, 'longitude': 78.39},
          {'id': 's2', 'name': 'Migrated', 'sequence': 2, 'status': 'needs_location'},
        ],
      });
      expect(route.stopsMissingLocation.length, 1);
      expect(route.stopsMissingLocation.single.stop.name, 'Migrated');
    });

    test('detects non-monotonic stop times — impossible before typed times', () {
      final bad = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'stops': [
          {'id': 's1', 'name': 'A', 'sequence': 1, 'pickupTime': '07:30',
           'latitude': 17.44, 'longitude': 78.39},
          {'id': 's2', 'name': 'B', 'sequence': 2, 'pickupTime': '07:05',
           'latitude': 17.45, 'longitude': 78.40},
        ],
      });
      expect(bad.hasNonMonotonicTimes, isTrue);

      final good = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'stops': [
          {'id': 's1', 'name': 'A', 'sequence': 1, 'pickupTime': '07:05',
           'latitude': 17.44, 'longitude': 78.39},
          {'id': 's2', 'name': 'B', 'sequence': 2, 'pickupTime': '07:30',
           'latitude': 17.45, 'longitude': 78.40},
        ],
      });
      expect(good.hasNonMonotonicTimes, isFalse);
    });

    test('reads canonical stop-time keys, with no scheduledTime alias', () {
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'stops': [
          {'id': 's1', 'name': 'A', 'sequence': 1,
           'pickupTime': '07:05', 'dropTime': '15:40',
           'latitude': 17.44, 'longitude': 78.39},
        ],
      });
      final s = route.stops.single;
      expect(s.pickupTime!.toWire(), '07:05');
      expect(s.dropTime!.toWire(), '15:40');
      expect(s.timesLabel, 'Pickup 7:05 AM · Drop 3:40 PM');
    });

    test('a legacy scheduledTime key is NOT silently honoured', () {
      // v2 is a clean break: the legacy key must not quietly work, or the two
      // shapes would coexist forever.
      final route = TransportRouteV2.fromJson({
        'id': 'r1',
        'name': 'R',
        'stops': [
          {'id': 's1', 'name': 'A', 'sequence': 1, 'scheduledTime': '07:05',
           'latitude': 17.44, 'longitude': 78.39},
        ],
      });
      expect(route.stops.single.pickupTime, isNull);
      expect(route.stops.single.timesLabel, 'Time not set');
    });
  });

  group('RouteCapacityV2 — null capacity means unbounded, never zero seats', () {
    test('no vehicle assigned reads as unbounded', () {
      final cap = RouteCapacityV2.fromJson({
        'routeName': 'R',
        'capacity': null,
        'current': 40,
      });
      expect(cap.unbounded, isTrue);
      expect(cap.capacity, isNull);
      // Reporting "40 / 0" would read as an over-full bus that has no seats.
      expect(cap.label, contains('no bus assigned'));
      expect(cap.wouldExceed(10), isFalse);
    });

    test('an assigned vehicle enforces its capacity', () {
      final cap = RouteCapacityV2.fromJson({
        'routeName': 'R',
        'capacity': 48,
        'current': 47,
      });
      expect(cap.unbounded, isFalse);
      expect(cap.wouldExceed(1), isFalse, reason: '48th child fits');
      expect(cap.wouldExceed(2), isTrue, reason: '49th child does not');
      expect(cap.label, '47 / 48');
    });
  });

  group('RouteReadinessV2 — blockers are actionable', () {
    test('parses blockers and exposes what to DO', () {
      final r = RouteReadinessV2.fromJson({
        'ready': false,
        'blockers': [
          'stops_missing_location',
          'no_vehicle_assigned',
          'no_driver_assigned',
        ],
      });
      expect(r.ready, isFalse);
      expect(r.blockers.length, 3);
      // The legacy activate endpoint gave NO signal at all about what was wrong.
      expect(r.blockers.map((b) => b.label),
          containsAll(<String>['Assign a bus', 'Assign a driver']));
    });

    test('an unknown blocker degrades to a safe label, never a crash', () {
      final r = RouteReadinessV2.fromJson({
        'ready': false,
        'blockers': ['some_future_blocker'],
      });
      expect(r.blockers.single, RouteBlocker.unknown);
      expect(r.blockers.single.label, isNotEmpty);
    });

    test('a ready route has no blockers', () {
      final r = RouteReadinessV2.fromJson({'ready': true, 'blockers': []});
      expect(r.ready, isTrue);
      expect(r.blockers, isEmpty);
    });
  });

  group('UnstaffedRouteV2 — says WHY the route has no crew', () {
    test('each reason maps to distinct operator guidance', () {
      final reasons = {
        'no_assignment': 'No bus or driver assigned',
        'no_driver': 'No driver assigned',
        'no_vehicle': 'No bus assigned',
        'driver_unavailable': 'Driver is on leave — assign a substitute',
      };
      reasons.forEach((wire, label) {
        final r = UnstaffedRouteV2.fromJson(
            {'routeId': 'r', 'routeName': 'R', 'missing': wire});
        expect(r.reasonLabel, label);
      });
    });
  });

  group('API paths — v2 only, never legacy', () {
    test('every path is under /transport/v2', () {
      final paths = <String>[
        TransportV2ApiPaths.routes,
        TransportV2ApiPaths.stops,
        TransportV2ApiPaths.unstaffedRoutes,
        TransportV2ApiPaths.route('r'),
        TransportV2ApiPaths.activateRoute('r'),
        TransportV2ApiPaths.deactivateRoute('r'),
        TransportV2ApiPaths.routeReadiness('r'),
        TransportV2ApiPaths.routeAssignment('r'),
        TransportV2ApiPaths.routeSubstitute('r'),
        TransportV2ApiPaths.routeCapacityCheck('r'),
        TransportV2ApiPaths.stop('s'),
        TransportV2ApiPaths.routeStops('r'),
        TransportV2ApiPaths.routeStop('r', 's'),
        TransportV2ApiPaths.routeStopsReorder('r'),
        TransportV2ApiPaths.vehicle('v'),
        TransportV2ApiPaths.driver('d'),
        TransportV2ApiPaths.driverAvailability('d'),
        TransportV2ApiPaths.assignment('a'),
      ];
      for (final p in paths) {
        expect(p, startsWith('/transport/v2/'), reason: '$p is not a v2 path');
      }
      expect(paths.length, 18);
    });
  });

  group('Error semantics — a refusal is not a fault', () {
    ApiFailure failure(String? code, ApiFailureType type) =>
        ApiFailure(type: type, message: 'x', code: code);

    test('a domain refusal is not retryable', () {
      // Retrying ROUTE_INCOMPLETE cannot help — the route is still incomplete.
      const state = TransportV2MutationState();
      final refused = TransportV2MutationState(
        failure: failure(TransportV2ErrorCodes.routeIncomplete,
            ApiFailureType.unknown),
      );
      expect(state.hasError, isFalse);
      expect(refused.isDomainRefusal, isTrue);
      expect(refused.isRetryable, isFalse);
    });

    test('a transport fault IS retryable and is not a domain refusal', () {
      final flaky = TransportV2MutationState(
        failure: failure(null, ApiFailureType.network),
      );
      expect(flaky.isRetryable, isTrue);
      expect(flaky.isDomainRefusal, isFalse);
    });

    test('a server error is retryable even when it carries a code', () {
      final boom = TransportV2MutationState(
        failure: failure('INTERNAL_ERROR', ApiFailureType.server),
      );
      expect(boom.isRetryable, isTrue);
      expect(boom.isDomainRefusal, isFalse);
    });

    test('every domain error code has operator guidance', () {
      const codes = [
        TransportV2ErrorCodes.routeIncomplete,
        TransportV2ErrorCodes.routeInUse,
        TransportV2ErrorCodes.stopInUse,
        TransportV2ErrorCodes.stopHasAllocations,
        TransportV2ErrorCodes.stopLocationRequired,
        TransportV2ErrorCodes.stopLocationInvalid,
        TransportV2ErrorCodes.capacityExceeded,
        TransportV2ErrorCodes.complianceBlocked,
        TransportV2ErrorCodes.driverUnavailable,
        TransportV2ErrorCodes.driverDoubleBooked,
        TransportV2ErrorCodes.vehicleDoubleBooked,
        TransportV2ErrorCodes.vehicleInUse,
        TransportV2ErrorCodes.driverInUse,
        TransportV2ErrorCodes.notASubstitute,
        TransportV2ErrorCodes.invalidTime,
        TransportV2ErrorCodes.nothingToAssign,
      ];
      for (final code in codes) {
        expect(transportV2Guidance(code), isNotEmpty,
            reason: '$code has no guidance — the code IS the instruction');
      }
    });

    test('INTERNAL_ERROR is not treated as actionable', () {
      expect(TransportV2ErrorCodes.isActionable('INTERNAL_ERROR'), isFalse);
      expect(TransportV2ErrorCodes.isActionable(null), isFalse);
      expect(TransportV2ErrorCodes.isActionable(''), isFalse);
      expect(
          TransportV2ErrorCodes.isActionable(
              TransportV2ErrorCodes.capacityExceeded),
          isTrue);
    });
  });

  group('Offline policy — reads may be stale, writes never queue', () {
    test('a fresh read is not marked stale', () {
      const r = RoutesResult(routes: [], isStale: false, cachedAt: null);
      expect(r.isStale, isFalse);
      expect(r.cachedAt, isNull);
    });

    test('a cached read carries its age so the UI can disclose it', () {
      final at = DateTime(2026, 7, 30, 6, 45);
      final r = RoutesResult(routes: const [], isStale: true, cachedAt: at);
      expect(r.isStale, isTrue);
      expect(r.cachedAt, at);
    });
  });
}
