import 'package:akshara_erp/features/library/catalog/library_catalog_screen.dart';
import 'package:akshara_erp/features/library/dashboard/library_dashboard_screen.dart';
import 'package:akshara_erp/features/library/fines/library_fines_screen.dart';
import 'package:akshara_erp/features/library/issues/library_issues_screen.dart';
import 'package:akshara_erp/features/library/members/library_members_screen.dart';
import 'package:akshara_erp/features/library/reports/library_reports_screen.dart';
import 'package:akshara_erp/features/library/resources/library_resources_screen.dart';
import 'package:akshara_erp/features/library/returns/library_returns_screen.dart';
import 'package:akshara_erp/features/library/library_providers.dart';
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

Future<void> pumpLibraryScreen(
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
  group('Library screens — desktop', () {
    testWidgets('LibraryDashboardScreen renders KPIs', (tester) async {
      await pumpLibraryScreen(tester, const LibraryDashboardScreen());

      expect(find.text('Total Books'), findsOneWidget);
      expect(find.text('Recent issues'), findsOneWidget);
    });

    testWidgets('LibraryDashboardScreen shows loading state', (tester) async {
      useViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            libraryDashboardLoadingProvider.overrideWith((ref) => true),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const LibraryDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('LibraryCatalogScreen renders book catalog', (tester) async {
      await pumpLibraryScreen(tester, const LibraryCatalogScreen());

      expect(find.text('Book catalog'), findsOneWidget);
      expect(find.text('Pride and Prejudice'), findsOneWidget);
    });

    testWidgets('LibraryIssuesScreen renders issue records', (tester) async {
      await pumpLibraryScreen(tester, const LibraryIssuesScreen());

      expect(find.text('Issue books'), findsOneWidget);
      expect(find.text('Arjun Patel'), findsOneWidget);
    });

    testWidgets('LibraryReturnsScreen renders return records', (tester) async {
      await pumpLibraryScreen(tester, const LibraryReturnsScreen());

      expect(find.text('Return books'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsOneWidget);
    });

    testWidgets('LibraryMembersScreen renders members', (tester) async {
      await pumpLibraryScreen(tester, const LibraryMembersScreen());

      expect(find.text('Library members'), findsOneWidget);
      expect(find.text('Emma Thomas'), findsOneWidget);
    });

    testWidgets('LibraryFinesScreen renders fines', (tester) async {
      await pumpLibraryScreen(tester, const LibraryFinesScreen());

      expect(find.text('Overdue fines'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('LibraryResourcesScreen renders digital resources', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, const LibraryResourcesScreen());

      expect(find.text('Digital resources'), findsOneWidget);
      expect(find.textContaining('NCERT Science'), findsOneWidget);
    });

    testWidgets('LibraryReportsScreen renders report catalog', (tester) async {
      await pumpLibraryScreen(tester, const LibraryReportsScreen());

      expect(find.text('Report catalog'), findsOneWidget);
      expect(find.textContaining('RPT-LB-001'), findsOneWidget);
    });
  });

  group('Library screens — error state', () {
    testWidgets('LibraryCatalogScreen shows error state', (tester) async {
      await pumpLibraryScreen(
        tester,
        const LibraryCatalogScreen(),
        overrides: [
          libraryCatalogErrorProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });
}
