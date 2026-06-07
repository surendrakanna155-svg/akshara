import 'package:akshara_erp/features/transport/allocation/transport_allocation_screen.dart';
import 'package:akshara_erp/features/transport/attendance/transport_attendance_screen.dart';
import 'package:akshara_erp/features/transport/dashboard/transport_dashboard_screen.dart';
import 'package:akshara_erp/features/transport/drivers/transport_drivers_screen.dart';
import 'package:akshara_erp/features/transport/reports/transport_reports_screen.dart';
import 'package:akshara_erp/features/transport/routes/transport_routes_screen.dart';
import 'package:akshara_erp/features/transport/settings/transport_settings_screen.dart';
import 'package:akshara_erp/features/transport/tracking/transport_tracking_screen.dart';
import 'package:akshara_erp/features/transport/vehicles/transport_vehicles_screen.dart';
import 'package:akshara_erp/features/transport/transport_providers.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helpers.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpTransportScreen(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(1440, 900),
  List<Override> overrides = const [],
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Transport screens — desktop', () {
    testWidgets('TransportDashboardScreen renders KPIs', (tester) async {
      await pumpTransportScreen(tester, const TransportDashboardScreen());

      expect(find.text('Active Buses'), findsOneWidget);
      expect(find.text('Live fleet assignments'), findsOneWidget);
    });

    testWidgets('TransportDashboardScreen shows loading state', (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            transportDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const TransportDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('TransportRoutesScreen renders route catalog', (tester) async {
      await pumpTransportScreen(tester, const TransportRoutesScreen());

      expect(find.text('Route catalog'), findsOneWidget);
      expect(find.text('Route 12 — North'), findsOneWidget);
    });

    testWidgets('TransportVehiclesScreen renders vehicle registry', (
      tester,
    ) async {
      await pumpTransportScreen(tester, const TransportVehiclesScreen());

      expect(find.text('Vehicle registry'), findsOneWidget);
      expect(find.text('BUS-07'), findsOneWidget);
    });

    testWidgets('TransportDriversScreen renders driver roster', (
      tester,
    ) async {
      await pumpTransportScreen(tester, const TransportDriversScreen());

      expect(find.text('Driver roster'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
    });

    testWidgets('TransportAllocationScreen renders SIS-linked students', (
      tester,
    ) async {
      await pumpTransportScreen(tester, const TransportAllocationScreen());

      expect(find.text('Student transport allocation'), findsOneWidget);
      expect(find.text('Arjun Patel'), findsOneWidget);
    });

    testWidgets('TransportAttendanceScreen renders attendance', (
      tester,
    ) async {
      await pumpTransportScreen(tester, const TransportAttendanceScreen());

      expect(find.text('AM pickup attendance'), findsOneWidget);
      expect(find.text('Emma Thomas'), findsOneWidget);
    });

    testWidgets('TransportTrackingScreen renders map placeholder', (
      tester,
    ) async {
      await pumpTransportScreen(tester, const TransportTrackingScreen());

      expect(find.text('Vehicle telemetry'), findsOneWidget);
      expect(find.textContaining('Google Maps'), findsWidgets);
    });

    testWidgets('TransportReportsScreen renders report catalog', (
      tester,
    ) async {
      await pumpTransportScreen(tester, const TransportReportsScreen());

      expect(find.text('Report catalog'), findsOneWidget);
      expect(find.text('On-Time Performance'), findsOneWidget);
    });

    testWidgets('TransportSettingsScreen renders settings', (tester) async {
      await pumpTransportScreen(tester, const TransportSettingsScreen());

      expect(find.text('Transport settings'), findsOneWidget);
      expect(find.text('GPS & tracking'), findsOneWidget);
    });
  });

  group('Transport screens — error state', () {
    testWidgets('TransportRoutesScreen shows error state', (tester) async {
      await pumpTransportScreen(
        tester,
        const TransportRoutesScreen(),
        overrides: [
          transportRoutesErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
