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

/// BUS-038/039/040 — route-stop sequence editor · ADMIN hop.
///
/// The legacy editor operated on a JSON array embedded in the route, using
/// up/down arrows, free-text times, and a form that submitted a drop time it had
/// never loaded — silently erasing it on any unrelated edit.
///
/// The two most consequential behaviours pinned here:
///   * a stop with NO LOCATION cannot be attached. Attaching one builds a route
///     that can never be published, with no obvious cause.
///   * attaching picks from EXISTING school stops, so a typed name can never
///     become a phantom stop the roster then groups children under.
TransportRouteV2 _route({List<Map<String, dynamic>> stops = const []}) =>
    TransportRouteV2.fromJson({
      'id': 'r1',
      'name': 'Route 12 — North',
      'shift': 'am',
      'status': 'draft',
      'stops': stops,
    });

Map<String, dynamic> _stopJson({
  required String id,
  required String name,
  int sequence = 1,
  String? pickup,
  String? drop,
  bool located = true,
}) =>
    {
      'id': id,
      'name': name,
      'sequence': sequence,
      if (located) 'latitude': 17.44 + sequence / 1000,
      if (located) 'longitude': 78.39 + sequence / 1000,
      if (!located) 'status': 'needs_location',
      if (pickup != null) 'pickupTime': pickup,
      if (drop != null) 'dropTime': drop,
    };

TransportStopV2 _schoolStop({
  required String id,
  required String name,
  bool located = true,
}) =>
    TransportStopV2.fromJson({
      'id': id,
      'name': name,
      if (located) 'latitude': 17.45,
      if (located) 'longitude': 78.40,
      if (!located) 'status': 'needs_location',
    });

void _useWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required TransportRouteV2 route,
  List<TransportStopV2> schoolStops = const [],
}) async {
  _useWideViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        transportV2EnabledProvider.overrideWithValue(true),
        transportV2RoutesProvider.overrideWith((ref) async =>
            RoutesResult(routes: [route], isStale: false, cachedAt: null)),
        transportV2UnstaffedProvider.overrideWith((ref) async => const []),
        transportV2StopsProvider.overrideWith((ref) async => StopsResult(
              stops: schoolStops,
              isStale: false,
              cachedAt: null,
            )),
        transportV2VehiclesProvider.overrideWith((ref) async => const []),
        transportV2DriversProvider.overrideWith((ref) async => const []),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: TransportV2RoutesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(QaTestKeys.transportV2ManageStopsButton('r1')));
  await tester.pumpAndSettle();
}

void main() {
  group('BUS-039 · the sequence editor', () {
    testWidgets('the route card shows a Stops action with the count',
        (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's1', name: 'A', sequence: 1),
        _stopJson(id: 's2', name: 'B', sequence: 2),
      ]));
      expect(find.byKey(QaTestKeys.transportV2ManageStopsButton('r1')),
          findsOneWidget);
      expect(find.text('Stops (2)'), findsOneWidget);
    });

    testWidgets('stops render in sequence order with their numbers',
        (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's2', name: 'Second', sequence: 2),
        _stopJson(id: 's1', name: 'First', sequence: 1),
      ]));
      await _openEditor(tester);

      // Order comes from `sequence`, never array position.
      final first =
          tester.getTopLeft(find.byKey(QaTestKeys.transportV2RouteStopTile('s1')));
      final second =
          tester.getTopLeft(find.byKey(QaTestKeys.transportV2RouteStopTile('s2')));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('reordering is a real drag list, not arrow buttons',
        (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's1', name: 'A', sequence: 1),
        _stopJson(id: 's2', name: 'B', sequence: 2),
        _stopJson(id: 's3', name: 'C', sequence: 3),
      ]));
      await _openEditor(tester);
      // Reordering eight stops with arrow taps is 20+ interactions.
      expect(find.byKey(QaTestKeys.transportV2StopReorderList), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('an empty route explains the two-stop minimum', (tester) async {
      await _pump(tester, route: _route());
      await _openEditor(tester);
      expect(find.textContaining('at least two'), findsOneWidget);
    });
  });

  group('BUS-037/040 · attaching picks an EXISTING located stop', () {
    testWidgets('the picker offers school stops not already on the route',
        (tester) async {
      await _pump(
        tester,
        route: _route(stops: [_stopJson(id: 's1', name: 'Already on')]),
        schoolStops: [
          _schoolStop(id: 's1', name: 'Already on'),
          _schoolStop(id: 's2', name: 'Available'),
        ],
      );
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2AttachStopButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2AttachStopDialog), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2AttachStopOption('s2')),
          findsOneWidget);
      // Already-attached stops must not be offered twice.
      expect(find.byKey(QaTestKeys.transportV2AttachStopOption('s1')), findsNothing);
    });

    testWidgets('an unlocated stop is shown but DISABLED, with the reason',
        (tester) async {
      await _pump(
        tester,
        route: _route(),
        schoolStops: [_schoolStop(id: 's9', name: 'Migrated', located: false)],
      );
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2AttachStopButton));
      await tester.pumpAndSettle();

      // Shown, so the admin knows where it went; disabled, because attaching it
      // would build a route that can never be published.
      expect(find.textContaining('set it before adding to a route'),
          findsOneWidget);
      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Migrated'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
    });

    testWidgets('no free-text stop name is offered anywhere', (tester) async {
      await _pump(
        tester,
        route: _route(),
        schoolStops: [_schoolStop(id: 's2', name: 'Available')],
      );
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2AttachStopButton));
      await tester.pumpAndSettle();

      // A typed name is how the legacy roster acquired phantom stops that
      // children were then grouped under by exact string match.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('an exhausted stop pool tells the admin to create one',
        (tester) async {
      await _pump(
        tester,
        route: _route(stops: [_stopJson(id: 's1', name: 'Only')]),
        schoolStops: [_schoolStop(id: 's1', name: 'Only')],
      );
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2AttachStopButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Create a new stop first'), findsOneWidget);
    });
  });

  group('BUS-038 · times are pickers, and honest when unset', () {
    testWidgets('the times dialog offers pickers, never a text field',
        (tester) async {
      await _pump(tester, route: _route(stops: [_stopJson(id: 's1', name: 'A')]));
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditStopTimesButton('s1')));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2StopTimesDialog), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2StopPickupTimeButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2StopDropTimeButton), findsOneWidget);
      // "7.05" / "morning" cannot be produced here at all.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('an unset time reads "Not set", never a fabricated default',
        (tester) async {
      await _pump(tester, route: _route(stops: [_stopJson(id: 's1', name: 'A')]));
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditStopTimesButton('s1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pickup: Not set'), findsOneWidget);
      expect(find.textContaining('Drop: Not set'), findsOneWidget);
    });

    testWidgets('BOTH persisted times prefill — the BUS-007 regression guard',
        (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's1', name: 'A', pickup: '07:05', drop: '15:40'),
      ]));
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditStopTimesButton('s1')));
      await tester.pumpAndSettle();

      // The legacy editor loaded pickup but NOT drop, then submitted the empty
      // drop — erasing it on an unrelated edit.
      expect(find.textContaining('Pickup: 7:05 AM'), findsOneWidget);
      expect(find.textContaining('Drop: 3:40 PM'), findsOneWidget);
    });

    testWidgets('the tile shows both times together', (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's1', name: 'A', pickup: '07:05', drop: '15:40'),
      ]));
      await _openEditor(tester);
      expect(find.text('Pickup 7:05 AM · Drop 3:40 PM'), findsOneWidget);
    });

    testWidgets('a stop with no times says so on the tile', (tester) async {
      await _pump(tester, route: _route(stops: [_stopJson(id: 's1', name: 'A')]));
      await _openEditor(tester);
      expect(find.text('Time not set'), findsOneWidget);
    });

    testWidgets('out-of-order pickup times warn, with the reason', (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's1', name: 'A', sequence: 1, pickup: '07:30'),
        _stopJson(id: 's2', name: 'B', sequence: 2, pickup: '07:05'),
      ]));
      await _openEditor(tester);

      expect(find.byKey(QaTestKeys.transportV2StopOrderWarning), findsOneWidget);
      // Only detectable because BUS-038 made times comparable.
      expect(find.textContaining('cannot reach a later stop earlier'),
          findsOneWidget);
    });
  });

  group('BUS-040 · detaching keeps the shared stop', () {
    testWidgets('detach explains the stop itself survives', (tester) async {
      await _pump(tester, route: _route(stops: [_stopJson(id: 's1', name: 'A')]));
      await _openEditor(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2DetachStopButton('s1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('stop itself is kept'), findsOneWidget);
      expect(find.textContaining('other routes'), findsOneWidget);
      expect(find.textContaining('must be moved first'), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2DetachStopConfirmButton),
          findsOneWidget);
    });

    testWidgets('an unlocated stop already on a route is flagged on its tile',
        (tester) async {
      await _pump(tester, route: _route(stops: [
        _stopJson(id: 's1', name: 'Migrated', located: false),
      ]));
      await _openEditor(tester);
      expect(find.textContaining('this route cannot go live'), findsOneWidget);
    });
  });
}
