import 'package:akshara_erp/core/testing/qa_test_keys.dart';
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
/// Proves the parent transport screen renders the active child's route/stop/
/// vehicle assignment.
///
/// BUS-001 — this suite previously PINNED the defect: it asserted the presence
/// of a "telemetry preview" card whose body was the compile-time constant
/// "Bus is approximately 8 minutes away", shown to every parent for every
/// child on every load. There is no ETA engine (BUS-091) and no position source
/// (Phase 9), so the roadmap's binding principle P-1 forbids any time-based
/// claim on this surface. The boundary test below is inverted accordingly: it
/// now fails if a fabricated ETA is ever reintroduced.
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
  required ParentTransportView view,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        parentTransportAllocationProvider.overrideWith((ref) async => view),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const ParentTransportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every string rendered anywhere in the current widget tree.
List<String> _renderedText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

void main() {
  group('QW5 · QA-J-006 parent transport view', () {
    testWidgets('renders the active child route, bus and pickup/drop',
        (tester) async {
      await _pump(tester, view: const ParentTransportView.available(_allocation));

      expect(find.text('Route 7 — North Loop'), findsOneWidget);
      expect(find.text('KA-01-AB-1234'), findsOneWidget);
      expect(find.text('Pickup: Green Park Gate'), findsOneWidget);
      expect(find.text('Drop: Sector 12 Market'), findsOneWidget);
    });

    testWidgets('shows the empty state when the child has no allocation',
        (tester) async {
      await _pump(tester, view: const ParentTransportView.noAllocation());

      expect(
        find.text('No transport allocation on file for this student.'),
        findsOneWidget,
      );
      expect(find.text('Route 7 — North Loop'), findsNothing);
    });

    testWidgets(
        'BUS-003 · renders the honest not-enabled state without a failure screen',
        (tester) async {
      await _pump(tester, view: const ParentTransportView.notEnabled());

      expect(
        find.byKey(QaTestKeys.parentTransportNotEnabledState),
        findsOneWidget,
      );
      expect(find.textContaining('once your school enables transport'),
          findsOneWidget);
      // Not-enabled is NOT an error: no retry affordance, no failure copy.
      expect(find.textContaining('Unable to load'), findsNothing);
    });

    testWidgets(
        'BUS-001 · surfaces NO fabricated ETA or time-based claim (P-1)',
        (tester) async {
      await _pump(tester, view: const ParentTransportView.available(_allocation));

      final rendered = _renderedText(tester).join(' | ').toLowerCase();

      // The exact fabricated strings that shipped before BUS-001.
      expect(rendered, isNot(contains('minutes away')));
      expect(rendered, isNot(contains('telemetry preview')));
      expect(rendered, isNot(contains('refresh eta')));
      expect(rendered, isNot(contains('approximately')));

      // Broader guard: no ETA/arrival claim of any shape until BUS-091 lands.
      expect(rendered, isNot(contains(' eta')));
      expect(rendered, isNot(contains('arriving')));
      expect(rendered, isNot(contains('min away')));
    });

    testWidgets('BUS-043 · unassigned bus renders honestly, never blank',
        (tester) async {
      const unassigned = StudentTransportAllocation(
        id: 'alloc-2',
        studentName: 'Ravi Kumar',
        admissionNumber: 'ADM-2031',
        classLabel: '8-A',
        pickupStop: 'Green Park Gate',
        dropStop: 'Sector 12 Market',
        routeId: 'route-7',
        routeName: 'Route 7 — North Loop',
        busNumber: '',
        shift: TransportShift.am,
        sisStudentId: 'SIS-STU-10430',
      );
      await _pump(tester, view: const ParentTransportView.available(unassigned));

      expect(find.text('Not assigned yet'), findsOneWidget);
    });
  });
}
