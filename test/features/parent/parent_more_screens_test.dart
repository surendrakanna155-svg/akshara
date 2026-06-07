import 'package:akshara_erp/features/parent/events/parent_events_provider.dart';
import 'package:akshara_erp/features/parent/events/parent_events_screen.dart';
import 'package:akshara_erp/features/parent/notices/parent_notices_provider.dart';
import 'package:akshara_erp/features/parent/notices/parent_notices_screen.dart';
import 'package:akshara_erp/features/parent/profile/parent_profile_provider.dart';
import 'package:akshara_erp/features/parent/profile/parent_profile_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

Future<void> pumpParentScreen(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
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
  group('Parent notices, events, and profile screens', () {
    testWidgets('ParentNoticesScreen renders notices list', (tester) async {
      await pumpParentScreen(tester, const ParentNoticesScreen());

      expect(find.text('School Notices'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(
        find.textContaining('PTM scheduled for 15 June'),
        findsOneWidget,
      );
    });

    testWidgets('ParentNoticesScreen shows loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentNoticesLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentNoticesScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('ParentEventsScreen renders upcoming events', (tester) async {
      await pumpParentScreen(tester, const ParentEventsScreen());

      expect(find.text('School Events'), findsOneWidget);
      expect(find.text('Science Exhibition'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
    });

    testWidgets('ParentEventsScreen shows empty state when forced empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentEventsEmptyProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentEventsScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaEmptyState), findsOneWidget);
    });

    testWidgets('ParentProfileScreen renders profile details', (tester) async {
      await pumpParentScreen(tester, const ParentProfileScreen());

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Ananya Kumar'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('ParentProfileScreen shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            parentProfileErrorProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ParentProfileScreen(),
          ),
        ),
      );
      useMobileViewport(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
