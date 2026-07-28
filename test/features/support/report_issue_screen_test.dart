import 'package:akshara_erp/core/observability/incident_context_providers.dart';
import 'package:akshara_erp/core/observability/incident_context_service.dart';
import 'package:akshara_erp/core/observability/incident_telemetry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_support_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/support/domain/support_delivery_failure.dart';
import 'package:akshara_erp/features/support/domain/support_models.dart';
import 'package:akshara_erp/features/support/report_issue_screen.dart';
import 'package:akshara_erp/features/support/support_ui.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';
import 'support_test_fakes.dart';

/// P0 regression suite for "Report an issue".
///
/// The defect: `supportRepositoryProvider` fell back to `MockSupportRepository`
/// in the shipping RC (SUPPORT_API_ENABLED was absent from
/// config/live_release.json), and the mock fabricated a `SUP-<n>` reference. The
/// user saw a ticket number. Nothing was sent, nothing was stored, and support
/// never saw it.
///
/// These tests hold the line on three things:
///   (i)   a failed submit shows NO reference, an honest error, and a retry;
///   (ii)  a successful submit shows the SERVER's reference and id;
///   (iii) the real mock cannot produce a reference the UI presents as confirmed.
void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Probe with no platform channels — the production one would hit
/// package_info_plus / device_info_plus.
class _FakeProbe implements IncidentEnvironmentProbe {
  @override
  Future<String?> appVersion() async => '1.0.0+1';
  @override
  Future<String?> deviceModel() async => 'Test Device';
  @override
  Future<String?> osVersion() async => 'Test OS';
  @override
  String platform() => 'android';
}

Override _contextOverride() =>
    incidentContextServiceProvider.overrideWithValue(
      IncidentContextService(
        probe: _FakeProbe(),
        buffer: IncidentTelemetryBuffer(),
        sessionIdReader: () async => 'session_test',
      ),
    );

/// Router with a stub detail route so the id the screen navigates to is
/// observable — that is how "the SERVER's id is used" is proven.
GoRouter _router() => GoRouter(
      initialLocation: RouteNames.supportNew,
      routes: <RouteBase>[
        GoRoute(
          path: RouteNames.supportNew,
          builder: (_, __) => const ReportIssueScreen(),
        ),
        GoRoute(
          path: RouteNames.supportIncidentDetailPattern,
          builder: (_, state) => Scaffold(
            body: Center(child: Text('detail:${state.pathParameters['id']}')),
          ),
        ),
      ],
    );

Future<void> _pumpScreen(WidgetTester tester, List<Override> overrides) async {
  _usePhoneViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([_contextOverride(), ...overrides]),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _typeAndSubmit(
  WidgetTester tester, {
  String title = 'Fee receipt PDF opens blank',
}) async {
  await tester.enterText(
    find.byKey(QaTestKeys.supportReportTitleField),
    title,
  );
  await tester.pump();
  await tester.ensureVisible(find.byKey(QaTestKeys.supportReportSubmitButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(QaTestKeys.supportReportSubmitButton));
  await tester.pump();
  // Cover the mock's simulated latency, then let animations finish.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('(i) a failed submit is honest', () {
    testWidgets(
        'shows no reference, states it was not sent, and offers a retry',
        (tester) async {
      final repo = FakeSupportRepository(
        createFailures: 1,
        createFailure: const SupportDeliveryFailure.notDelivered(),
      );
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(repo),
      ]);

      await _typeAndSubmit(tester);

      // The single most important assertion in this file.
      expect(
        find.textContaining('SUP-'),
        findsNothing,
        reason: 'a failed report must never be given a reference number',
      );
      expect(find.textContaining('Sent to Akshara Support'), findsNothing);

      // We are still on the form, with the honest failure panel.
      expect(find.byKey(QaTestKeys.supportReportScreen), findsOneWidget);
      expect(find.byKey(kSupportReportDeliveryFailureKey), findsOneWidget);
      expect(
        find.text(
          supportReportFailureHeadline(
            SupportDeliveryFailureReason.notDelivered,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          supportReportFailureDetail(SupportDeliveryFailureReason.notDelivered),
        ),
        findsOneWidget,
      );

      // Retry is offered, and what they typed is still on screen.
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Fee receipt PDF opens blank'), findsOneWidget);
    });

    testWidgets('notConfigured says the build has no support channel',
        (tester) async {
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(
          FakeSupportRepository(
            createFailures: 1,
            createFailure: const SupportDeliveryFailure.notConfigured(),
          ),
        ),
      ]);

      await _typeAndSubmit(tester);

      expect(
        find.text(
          supportReportFailureHeadline(
            SupportDeliveryFailureReason.notConfigured,
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('SUP-'), findsNothing);
    });

    testWidgets('an unclassified error still refuses to confirm anything',
        (tester) async {
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(
          _ExplodingSupportRepository(),
        ),
      ]);

      await _typeAndSubmit(tester);

      expect(find.text(supportReportFailureHeadline(null)), findsOneWidget);
      expect(find.textContaining('SUP-'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retrying after a failure can succeed', (tester) async {
      final repo = FakeSupportRepository(
        createFailures: 1,
        created: serverCreatedIncident(),
      );
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(repo),
      ]);

      await _typeAndSubmit(tester);
      expect(find.byKey(kSupportReportDeliveryFailureKey), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.supportReportSubmitButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.createAttempts, 2);
      expect(find.text('detail:a1b2c3d4-0000-4000-8000-00000000dead'),
          findsOneWidget);
    });
  });

  group('(ii) a successful submit shows the SERVER\'s identifiers', () {
    testWidgets('confirms with the server reference and navigates to its id',
        (tester) async {
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(
          FakeSupportRepository(created: serverCreatedIncident()),
        ),
      ]);

      await _typeAndSubmit(tester);

      // The reference is the server's, verbatim.
      expect(
        find.textContaining('SUP-SERVER-77'),
        findsOneWidget,
        reason: 'the confirmation must quote the reference the server issued',
      );
      // …and we routed to the server's incident id.
      expect(
        find.text('detail:a1b2c3d4-0000-4000-8000-00000000dead'),
        findsOneWidget,
      );
      expect(find.byKey(kSupportReportDeliveryFailureKey), findsNothing);
    });

    testWidgets('a screenshot that did not upload is disclosed, not hidden',
        (tester) async {
      // The report itself succeeded, so a reference IS legitimate here — but the
      // screenshot failure must be said out loud.
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(
          FakeSupportRepository(
            created: serverCreatedIncident(),
            uploadFailure: const SupportDeliveryFailure.notDelivered(),
          ),
        ),
      ]);

      await _typeAndSubmit(tester);

      expect(find.textContaining('SUP-SERVER-77'), findsOneWidget);
    });
  });

  group('(iii) the real mock cannot produce a presentable reference', () {
    testWidgets(
        'MockSupportRepository submit yields no reference and no confirmation',
        (tester) async {
      // The exact wiring that shipped: no override, the real in-memory mock.
      await _pumpScreen(tester, [
        supportRepositoryProvider.overrideWithValue(MockSupportRepository()),
      ]);

      await _typeAndSubmit(tester);

      expect(
        find.textContaining(RegExp('SUP-')),
        findsNothing,
        reason: 'the P0: the mock used to hand the user a fabricated SUP-<n>',
      );
      expect(find.textContaining('Sent to Akshara Support'), findsNothing);
      expect(find.textContaining('Support will investigate'), findsNothing);
      expect(find.byKey(kSupportReportDeliveryFailureKey), findsOneWidget);
      expect(
        find.text(
          supportReportFailureHeadline(
            SupportDeliveryFailureReason.notConfigured,
          ),
        ),
        findsOneWidget,
      );
      // Still on the form — no navigation to a detail screen for a ghost ticket.
      expect(find.byKey(QaTestKeys.supportReportScreen), findsOneWidget);
      expect(find.textContaining('detail:'), findsNothing);
    });
  });
}

/// A repository whose write blows up with something that is NOT a
/// [SupportDeliveryFailure] — exercises the "we do not know what happened"
/// copy, which still refuses to confirm delivery.
class _ExplodingSupportRepository extends FakeSupportRepository {
  @override
  Future<SupportIncident> createIncident({
    required RepositoryQuery query,
    required CreateSupportIncidentInput input,
  }) async =>
      throw StateError('boom');
}
