import 'package:akshara_erp/features/parent/transport/parent_transport_provider.dart';
import 'package:akshara_erp/features/parent/transport/parent_transport_screen.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW5 · QA-J-006 — Parent · view child transport status / route.
///
/// Previously nav-only. This proves the parent transport screen actually
/// RENDERS the active child's static route/stop/vehicle assignment (the row's
/// "assertVisible route detail for child"). Live GPS / map tracking is
/// intentionally out of scope (owner decision O8 — Phase 2): the screen shows a
/// telemetry-preview note and explicitly states live-map is not enabled, which
/// this test pins so the Phase-2 boundary cannot silently regress into a
/// "live tracking" claim.
const _allocation = StudentTransportAllocation(
  id: 'alloc-1',
  studentName: 'Ravi Kumar',
  admissionNumber: 'ADM-2031',
  classLabel: '8-A',
  pickupStop: 'Green Park Gate',
  dropStop: 'Sector 12 Market',
  routeId: 'route-7',
  routeName: 'Route 7 — North Loop',
  busNumber: 'KA-01-AB-1234',
  shift: TransportShift.am,
  sisStudentId: 'SIS-STU-10430',
);

Future<void> _pump(
  WidgetTester tester, {
  required StudentTransportAllocation? allocation,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        parentTransportAllocationProvider.overrideWith((ref) async => allocation),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ParentTransportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QW5 · QA-J-006 parent transport view', () {
    testWidgets('renders the active child route, bus and pickup/drop',
        (tester) async {
      await _pump(tester, allocation: _allocation);

      expect(find.text('Route 7 — North Loop'), findsOneWidget);
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.text('Pickup: Green Park Gate'), findsOneWidget);
      expect(find.text('Drop: Sector 12 Market'), findsOneWidget);
    });

    testWidgets('shows the empty state when the child has no allocation',
        (tester) async {
      await _pump(tester, allocation: null);

      expect(
        find.text('No transport allocation on file for this student.'),
        findsOneWidget,
      );
      expect(find.text('Route 7 — North Loop'), findsNothing);
    });

    testWidgets('pins the Phase-2 boundary — telemetry preview, no live map',
        (tester) async {
      await _pump(tester, allocation: _allocation);

      expect(
        find.textContaining('Live map integration is not enabled'),
        findsOneWidget,
      );
    });
  });
}
