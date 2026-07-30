import 'package:akshara_erp/core/repositories/api/transport/v2/transport_v2_repository.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/transport/v2/stops/transport_v2_stops_screen.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_models.dart';
import 'package:akshara_erp/features/transport/v2/transport_v2_providers.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// BUS-036/037/038/039/040 — Transport v2 stop manager · ADMIN hop.
///
/// The load-bearing test in this file is the coordinate one. A stop without a
/// location is the single defect that made the entire tracking feature
/// unreachable pre-v2: the write path accepted only {name, pickupTime,
/// dropTime}, so every stop a real school created sat at 0°N 0°E. These tests
/// prove the UI cannot produce that state.
TransportStopV2 _stop({
  String id = 's1',
  String name = 'Green Park Gate',
  double? lat = 17.4484,
  double? lng = 78.3908,
  String status = 'active',
  int radius = 100,
  String address = '',
  String landmark = '',
}) {
  return TransportStopV2.fromJson({
    'id': id,
    'name': name,
    if (lat != null) 'latitude': lat,
    if (lng != null) 'longitude': lng,
    'status': status,
    'geofenceRadiusM': radius,
    'addressText': address,
    'landmark': landmark,
  });
}

void _useWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required List<TransportStopV2> stops,
  bool enabled = true,
  bool isStale = false,
}) async {
  _useWideViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        transportV2EnabledProvider.overrideWithValue(enabled),
        transportV2StopsProvider.overrideWith((ref) async => StopsResult(
              stops: stops,
              isStale: isStale,
              cachedAt: isStale ? DateTime(2026, 7, 30, 6, 45) : null,
            )),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: TransportV2StopsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCreateForm(WidgetTester tester) async {
  await tester.tap(find.byKey(QaTestKeys.transportV2CreateStopButton));
  await tester.pumpAndSettle();
}

void main() {
  group('BUS-037 · a stop cannot be created without a location', () {
    testWidgets('submitting with no coordinate is refused, with a reason',
        (tester) async {
      await _pump(tester, stops: const []);
      await _openCreateForm(tester);

      await tester.enterText(
          find.byKey(QaTestKeys.transportV2StopNameField), 'Green Park Gate');
      await tester.tap(find.byKey(QaTestKeys.transportV2StopFormSubmitButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2StopLocationError), findsOneWidget);
      // The dialog stays open so the admin can fix it.
      expect(find.byKey(QaTestKeys.transportV2StopFormDialog), findsOneWidget);
    });

    testWidgets('(0,0) is refused BY NAME — it is not a real stop', (tester) async {
      await _pump(tester, stops: const []);
      await _openCreateForm(tester);

      await tester.enterText(
          find.byKey(QaTestKeys.transportV2StopNameField), 'Nowhere');
      await tester.enterText(find.byKey(QaTestKeys.transportV2StopLatField), '0');
      await tester.enterText(find.byKey(QaTestKeys.transportV2StopLngField), '0');
      await tester.tap(find.byKey(QaTestKeys.transportV2StopFormSubmitButton));
      await tester.pumpAndSettle();

      // An admin who typed zeros must be told zeros are not usable, rather than
      // silently getting a stop in the Atlantic — which is exactly what the
      // legacy path produced for every stop it ever created.
      expect(find.textContaining('0, 0 is not a real stop location'),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2StopFormDialog), findsOneWidget);
    });

    testWidgets('an out-of-range coordinate is refused', (tester) async {
      await _pump(tester, stops: const []);
      await _openCreateForm(tester);

      await tester.enterText(
          find.byKey(QaTestKeys.transportV2StopNameField), 'Bad');
      await tester.enterText(find.byKey(QaTestKeys.transportV2StopLatField), '95');
      await tester.enterText(find.byKey(QaTestKeys.transportV2StopLngField), '78.4');
      await tester.tap(find.byKey(QaTestKeys.transportV2StopFormSubmitButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2StopLocationError), findsOneWidget);
    });

    testWidgets('a blank name is refused before the location check',
        (tester) async {
      await _pump(tester, stops: const []);
      await _openCreateForm(tester);
      await tester.tap(find.byKey(QaTestKeys.transportV2StopFormSubmitButton));
      await tester.pumpAndSettle();

      expect(find.text('Stop name is required'), findsOneWidget);
    });

    testWidgets('the form states the map picker is still to come', (tester) async {
      await _pump(tester, stops: const []);
      await _openCreateForm(tester);
      // BUS-086 seam, disclosed rather than silently missing.
      expect(find.textContaining('Map pin-drop arrives'), findsOneWidget);
    });
  });

  group('BUS-030 · migrated stops with no location are LOUD', () {
    testWidgets('a needs_location stop is chipped and banner-counted',
        (tester) async {
      await _pump(tester, stops: [
        _stop(id: 's1', name: 'Migrated', lat: null, lng: null,
            status: 'needs_location'),
        _stop(id: 's2', name: 'Located'),
      ]);

      expect(find.byKey(QaTestKeys.transportV2NeedsLocationBanner), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2NeedsLocationChip('s1')),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2NeedsLocationChip('s2')), findsNothing);
      // The consequence is spelled out, not implied.
      expect(find.textContaining('cannot go live'), findsOneWidget);
    });

    testWidgets('its action reads "Set location", not a generic Edit',
        (tester) async {
      await _pump(tester, stops: [
        _stop(id: 's1', lat: null, lng: null, status: 'needs_location'),
      ]);
      expect(find.text('Set location'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('unlocated stops sort to the top of the list', (tester) async {
      await _pump(tester, stops: [
        _stop(id: 's1', name: 'Aaa Located'),
        _stop(id: 's2', name: 'Zzz Migrated', lat: null, lng: null,
            status: 'needs_location'),
      ]);
      // Work-to-do first: an admin should not have to hunt for the blockers.
      final unlocated = tester.getTopLeft(
          find.byKey(QaTestKeys.transportV2StopCard('s2')));
      final located = tester.getTopLeft(
          find.byKey(QaTestKeys.transportV2StopCard('s1')));
      expect(unlocated.dy, lessThan(located.dy));
    });

    testWidgets('no banner when every stop is located', (tester) async {
      await _pump(tester, stops: [_stop()]);
      expect(find.byKey(QaTestKeys.transportV2NeedsLocationBanner), findsNothing);
    });
  });

  group('BUS-036 · stop editing prefills and preserves', () {
    testWidgets('the edit form loads the persisted coordinate and radius',
        (tester) async {
      await _pump(tester, stops: [
        _stop(radius: 250, address: '12 Lake View Rd', landmark: 'by the temple'),
      ]);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditStopButton('s1')));
      await tester.pumpAndSettle();

      // A form that submits what it never loaded is how BUS-007 erased data.
      expect(find.text('Green Park Gate'), findsWidgets);
      expect(find.text('17.448400'), findsOneWidget);
      expect(find.text('78.390800'), findsOneWidget);
      expect(find.textContaining('250 m'), findsWidgets);
      expect(find.text('12 Lake View Rd'), findsOneWidget);
      expect(find.text('by the temple'), findsOneWidget);
    });

    testWidgets('a half-typed coordinate on edit is a mistake, not a clear',
        (tester) async {
      await _pump(tester, stops: [_stop()]);
      await tester.tap(find.byKey(QaTestKeys.transportV2EditStopButton('s1')));
      await tester.pumpAndSettle();

      // Latitude emptied, longitude left set: ambiguous, so refuse rather than
      // guess whether the admin meant to clear the location.
      await tester.enterText(find.byKey(QaTestKeys.transportV2StopLatField), '');
      await tester.tap(find.byKey(QaTestKeys.transportV2StopFormSubmitButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.transportV2StopLocationError), findsOneWidget);
    });

    testWidgets('the card shows the coordinate and geofence radius',
        (tester) async {
      await _pump(tester, stops: [_stop(radius: 150)]);
      expect(find.textContaining('17.44840'), findsOneWidget);
      expect(find.textContaining('geofence 150 m'), findsOneWidget);
    });
  });

  group('BUS-040 · shared stops delete safely', () {
    testWidgets('delete warns that stops are shared across routes',
        (tester) async {
      await _pump(tester, stops: [_stop()]);
      await tester.tap(find.byKey(QaTestKeys.transportV2DeleteStopButton('s1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('may'), findsOneWidget);
      expect(find.textContaining('more than one route'), findsOneWidget);
      expect(find.byKey(QaTestKeys.transportV2DeleteStopConfirmButton),
          findsOneWidget);
    });
  });

  group('Screen states', () {
    testWidgets('an unmigrated school is told, not shown an error',
        (tester) async {
      await _pump(tester, stops: const [], enabled: false);
      expect(find.byKey(QaTestKeys.transportV2NotEnabledState), findsOneWidget);
    });

    testWidgets('the empty state explains the location requirement',
        (tester) async {
      await _pump(tester, stops: const []);
      expect(find.textContaining('needs a location before a route can go live'),
          findsOneWidget);
    });

    testWidgets('cached data is disclosed, never shown as live', (tester) async {
      await _pump(tester, stops: [_stop()], isStale: true);
      expect(find.byKey(QaTestKeys.transportV2StaleBanner), findsOneWidget);
    });
  });
}
