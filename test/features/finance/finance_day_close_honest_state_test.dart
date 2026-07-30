import 'dart:async';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_screen.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/policy/finance_policy_provider.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// FIN-D1 · honest state — the day-close lock is a MONEY surface. Telling a
/// finance manager "No day closed yet" while the read is still in flight or has
/// failed is a false factual claim they may act on (re-collecting into a day
/// that is actually locked). Loading, error and genuinely-empty must each be
/// stated as themselves, and the raw transport exception must never surface.

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpCollections(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceCollectionsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
}

void main() {
  group('FIN-D1 · day-close status is honest about unknown state', () {
    testWidgets('a resolved, genuinely empty read still says "No day closed yet"',
        (tester) async {
      await _pumpCollections(
        tester,
        overrides: [
          financeDayCloseEntriesFutureProvider
              .overrideWith((ref) async => const <DayCloseEntry>[]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No day closed yet'), findsOneWidget);
      expect(find.byKey(QaTestKeys.financeCloseDayButton), findsOneWidget);
    });

    testWidgets('an in-flight read does NOT claim the day is open',
        (tester) async {
      final pending = Completer<List<DayCloseEntry>>();
      addTearDown(() => pending.complete(const <DayCloseEntry>[]));

      await _pumpCollections(
        tester,
        overrides: [
          financeDayCloseEntriesFutureProvider
              .overrideWith((ref) => pending.future),
        ],
      );
      await tester.pump();

      expect(find.text('Day-close lock'), findsOneWidget);
      expect(find.text('No day closed yet'), findsNothing);
      expect(find.text('Checking day-close status…'), findsOneWidget);
    });

    testWidgets('a failed read says so, and never leaks the raw exception',
        (tester) async {
      await _pumpCollections(
        tester,
        overrides: [
          financeDayCloseEntriesFutureProvider.overrideWith(
            (ref) async => throw DioException(
              requestOptions: RequestOptions(
                path: '/functions/v1/finance-day-close',
                baseUrl: 'https://internal-db.akshara.invalid',
              ),
              type: DioExceptionType.connectionError,
              message: 'SocketException: Failed host lookup',
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Day-close lock'), findsOneWidget);
      // The false "the day is open" claim is gone…
      expect(find.text('No day closed yet'), findsNothing);
      // …replaced by an honest, mapped statement of the unknown state.
      expect(
        find.textContaining('Day-close status unavailable'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Unable to reach the server'),
        findsOneWidget,
      );

      for (final leak in const [
        'DioException',
        'internal-db.akshara.invalid',
        'finance-day-close',
        'SocketException',
      ]) {
        expect(
          find.textContaining(leak),
          findsNothing,
          reason: 'raw exception detail "$leak" reached the UI',
        );
      }
    });
  });
}
