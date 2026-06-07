import 'package:akshara_erp/features/alumni/campaigns/alumni_campaigns_screen.dart';
import 'package:akshara_erp/features/alumni/dashboard/alumni_dashboard_screen.dart';
import 'package:akshara_erp/features/alumni/donations/alumni_donations_screen.dart';
import 'package:akshara_erp/features/alumni/events/alumni_events_screen.dart';
import 'package:akshara_erp/features/alumni/mentorship/alumni_mentorship_screen.dart';
import 'package:akshara_erp/features/alumni/profile/alumni_profile_screen.dart';
import 'package:akshara_erp/features/alumni/registry/alumni_registry_screen.dart';
import 'package:akshara_erp/features/alumni/reports/alumni_reports_screen.dart';
import 'package:akshara_erp/features/alumni/settings/alumni_settings_screen.dart';
import 'package:akshara_erp/features/alumni/alumni_providers.dart';
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

Future<void> pumpAlumniScreen(
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
  group('Alumni screens — desktop', () {
    testWidgets('AlumniDashboardScreen renders KPIs', (tester) async {
      await pumpAlumniScreen(tester, const AlumniDashboardScreen());

      expect(find.text('Total Alumni'), findsOneWidget);
      expect(find.text('Recent SIS graduates'), findsOneWidget);
    });

    testWidgets('AlumniDashboardScreen shows loading state', (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            alumniDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AlumniDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('AlumniRegistryScreen renders alumni registry', (
      tester,
    ) async {
      await pumpAlumniScreen(tester, const AlumniRegistryScreen());

      expect(find.text('Alumni registry'), findsOneWidget);
      expect(find.text('Arjun Patel'), findsOneWidget);
    });

    testWidgets('AlumniProfileScreen renders alumni profile', (tester) async {
      await pumpAlumniScreen(
        tester,
        const AlumniProfileScreen(alumniId: 'ALM-001'),
      );

      expect(find.text('Arjun Patel'), findsAtLeastNWidgets(1));
      expect(find.text('Employment history'), findsOneWidget);
    });

    testWidgets('AlumniEventsScreen renders event calendar', (tester) async {
      await pumpAlumniScreen(tester, const AlumniEventsScreen());

      expect(find.text('Event calendar'), findsOneWidget);
      expect(find.text('Annual Alumni Reunion 2026'), findsOneWidget);
    });

    testWidgets('AlumniDonationsScreen renders donation ledger', (
      tester,
    ) async {
      await pumpAlumniScreen(tester, const AlumniDonationsScreen());

      expect(find.text('Donation ledger'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('AlumniCampaignsScreen renders campaigns', (tester) async {
      await pumpAlumniScreen(tester, const AlumniCampaignsScreen());

      expect(find.text('Fundraising campaigns'), findsOneWidget);
      expect(find.text('Library Fund 2026'), findsOneWidget);
    });

    testWidgets('AlumniMentorshipScreen renders mentorship pairs', (
      tester,
    ) async {
      await pumpAlumniScreen(tester, const AlumniMentorshipScreen());

      expect(find.text('Mentorship pairs'), findsOneWidget);
      expect(find.text('Kavya Iyer'), findsOneWidget);
    });

    testWidgets('AlumniReportsScreen renders report catalog', (tester) async {
      await pumpAlumniScreen(tester, const AlumniReportsScreen());

      expect(find.text('Report catalog'), findsOneWidget);
      expect(find.text('Donation Ledger'), findsOneWidget);
    });

    testWidgets('AlumniSettingsScreen renders settings', (tester) async {
      await pumpAlumniScreen(tester, const AlumniSettingsScreen());

      expect(find.text('Alumni settings'), findsOneWidget);
      expect(find.text('AL-10 — Mobile Companion'), findsOneWidget);
    });
  });

  group('Alumni screens — error state', () {
    testWidgets('AlumniRegistryScreen shows error state', (tester) async {
      await pumpAlumniScreen(
        tester,
        const AlumniRegistryScreen(),
        overrides: [
          alumniRegistryErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
