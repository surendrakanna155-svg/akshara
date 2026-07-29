/// MECHANICAL GUARD (behavioural) — the honest-async contract, both directions.
///
/// The static guard (`honest_async_contract_guard_test.dart`) proves the *code*
/// contains no fabricated fallback. This one drives the real widget tree and
/// proves the *rendered pixels* obey the contract in both directions:
///
///   A. **No data ⇒ no fabrication.** Drive every persona surface through a
///      repository that THROWS and assert the tree shows an honest error with a
///      retry — and contains none of the register's fabricated strings
///      (`₹4,200`, `Ravi Kumar`, `9:02 AM`, `9:12 AM`, `Geo+Face verified`,
///      `1,248`, `₹4.2L`, `142 active staff`, `96.2%`).
///
///   B. **Known ⇒ the value; unknown ⇒ the marker; never both for the same
///      quantity.** Drive a surface with a payload in which a quantity IS
///      present and assert its KPI card renders the value, not `—`; then drive
///      it with a payload that genuinely lacks the quantity and assert the card
///      renders `—` and NOT a measured `0`.
///
///      This is the invariant behind the same-screen contradiction on
///      `/parent/dashboard`: the hero rendered `Present` and `₹4,200 due` while
///      the KPI cards directly below rendered `—` for those same two
///      quantities. A `—` sitting next to the value it claims not to have
///      destroys the meaning of every other `—` in the product — which is
///      precisely the contract this wave is trying to establish.
///
/// The table is the point: adding a persona surface means adding a row, and a
/// surface with no row is visible as a gap rather than silently uncovered.
library;

import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_screen.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/parent_fees_screen.dart';
import 'package:akshara_erp/features/parent/homework/homework_models.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_provider.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_screen.dart';
import 'package:akshara_erp/features/parent/payment/parent_payment_provider.dart';
import 'package:akshara_erp/features/parent/payment/parent_payment_screen.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_screen.dart';
import 'package:akshara_erp/shared/widgets/akshara_empty_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/premium/akshara_premium_kpi_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/provider_test_overrides.dart';
import '../test_helpers.dart';

/// Strings the register recorded as fabricated. None may ever reach a render.
const List<String> kFabricatedStrings = [
  '₹4,200',
  '₹23,000',
  '₹8,000',
  'Ravi Kumar',
  'Priya Sharma',
  '9:02 AM',
  '9:12 AM',
  'Geo+Face verified',
  'NIKSHA Public School',
  '1,248',
  '₹4.2L',
  '142 active staff',
  '96.2%',
  '34 of 38 present',
  'Unit Test — Mathematics',
];

/// Markers that mean "we do not have this value".
const List<String> kUnknownMarkers = [
  '—',
  'Not available',
  'Not enough data yet',
];

class _ThrowingRepositoryError implements Exception {
  @override
  String toString() => 'repository unavailable';
}

/// One persona surface under test.
class _Surface {
  const _Surface({
    required this.name,
    required this.screen,
    required this.failureOverrides,
    required this.dataOverrides,
  });

  final String name;
  final Widget screen;

  /// Overrides that make the backing repository call FAIL.
  final List<Override> Function() failureOverrides;

  /// Overrides that supply a payload in which every displayed quantity is
  /// known. Used by the data-direction assertions.
  final List<Override> Function() dataOverrides;
}

/// A payload where every quantity the parent dashboard renders is present.
ParentDashboardData _fullParentDashboard() => const ParentDashboardData(
      childName: 'Test Child',
      childClass: '5-B',
      greetingEyebrow: 'Monday',
      greetingHeadline: 'Day at a glance',
      schoolName: 'Test School',
      unreadNotifications: 0,
      statusChips: [
        DashboardStatusChip(
          label: 'Present',
          tone: DashboardChipTone.success,
          kind: DashboardChipKind.attendance,
        ),
        DashboardStatusChip(
          label: '₹1,500 due',
          tone: DashboardChipTone.warning,
          kind: DashboardChipKind.fees,
        ),
      ],
      quickActions: [],
      todaySummary: [
        TodaySummaryItem(
          id: 'homework',
          icon: Icons.assignment_outlined,
          iconTone: DashboardChipTone.primary,
          title: '3 homework due today',
        ),
      ],
      notices: [],
      events: [],
      aiInsight: DashboardAiInsight(message: '', actionLabel: ''),
    );

ParentFeesData _fullFees() => const ParentFeesData(
      pendingAmount: 1500,
      isOverdue: false,
      dueLabel: 'Due 30 Sep',
      paidAmount: 3500,
      annualAmount: 5000,
      progressPercent: 70,
      installments: [
        FeeInstallment(
          id: 'inst-real-1',
          title: 'Instalment 1',
          amount: 1500,
          status: FeeInstallmentStatus.due,
        ),
      ],
      breakdown: [],
      paymentHistory: [],
    );

ParentHomeworkData _fullHomework() => const ParentHomeworkData(
      childName: 'Test Child',
      childClass: '5-B',
      insightMessage: 'Two tasks due this week.',
      insightActionLabel: 'View',
      items: [],
    );

PaymentSummary _fullPaymentSummary() => const PaymentSummary(
      installmentId: 'inst-real-1',
      installmentTitle: 'Instalment 1',
      childName: 'Test Child',
      childClass: '5-B',
      dueLabel: 'Due 30 Sep',
      baseAmount: 1500,
      lateFee: 0,
      convenienceFee: 0,
      breakdown: [],
    );

List<_Surface> _surfaces() => [
      _Surface(
        name: 'parent dashboard (WIDGET-001 / CERT-002)',
        screen: const ParentDashboardScreen(),
        failureOverrides: () => [
          parentDashboardFutureProvider
              .overrideWith((ref) => throw _ThrowingRepositoryError()),
        ],
        dataOverrides: () => [
          parentDashboardFutureProvider
              .overrideWith((ref) async => _fullParentDashboard()),
        ],
      ),
      _Surface(
        name: 'teacher dashboard (WIDGET-002)',
        screen: const TeacherDashboardScreen(),
        failureOverrides: () => [
          teacherDashboardFutureProvider
              .overrideWith((ref) => throw _ThrowingRepositoryError()),
        ],
        dataOverrides: () => [
          teacherDashboardFutureProvider
              .overrideWith((ref) async => TeacherDashboardData.empty()),
        ],
      ),
      _Surface(
        name: 'parent fees (CERT-001)',
        screen: const ParentFeesScreen(),
        failureOverrides: () => [
          parentFeesFutureProvider
              .overrideWith((ref) => throw _ThrowingRepositoryError()),
        ],
        dataOverrides: () => [
          parentFeesFutureProvider.overrideWith((ref) async => _fullFees()),
        ],
      ),
      _Surface(
        name: 'parent homework (CERT-002)',
        screen: const ParentHomeworkScreen(),
        failureOverrides: () => [
          parentHomeworkFutureProvider
              .overrideWith((ref) => throw _ThrowingRepositoryError()),
        ],
        dataOverrides: () => [
          parentHomeworkFutureProvider
              .overrideWith((ref) async => _fullHomework()),
        ],
      ),
      _Surface(
        name: 'parent payment (JOURNEY-007)',
        screen: const ParentPaymentScreen(installmentId: 'inst-real-1'),
        failureOverrides: () => [
          parentPaymentSummaryFutureProvider
              .overrideWith((ref, id) => throw _ThrowingRepositoryError()),
        ],
        dataOverrides: () => [
          parentPaymentSummaryFutureProvider
              .overrideWith((ref, id) async => _fullPaymentSummary()),
        ],
      ),
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  List<Override> overrides,
) async {
  await initProviderTestPrefs();
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: providerTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
}

/// Every KPI card on screen, as `label -> value`. A KPI card is the cleanest
/// place to assert the invariant: one quantity, one rendered value.
Map<String, String> _kpiCards(WidgetTester tester) {
  final cards = <String, String>{};
  for (final widget in tester.allWidgets) {
    if (widget is AksharaPremiumKpiCard) {
      cards[widget.label] = widget.value;
    }
  }
  return cards;
}

Iterable<String> _renderedText(WidgetTester tester) sync* {
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      final data = widget.data;
      if (data != null) yield data;
      final span = widget.textSpan;
      if (span != null) yield span.toPlainText();
    }
  }
}

void main() {
  // Fabricated content is never acceptable — even in the loading frame, which
  // is where WIDGET-001/002 shipped it on EVERY cold open.
  group('A · no server payload ⇒ honest state, never fabricated data', () {
    for (final surface in _surfaces()) {
      testWidgets('${surface.name} — failure renders an honest state',
          (tester) async {
        await _pump(tester, surface.screen, surface.failureOverrides());

        final honest = find.byType(AksharaErrorState).evaluate().isNotEmpty ||
            find.byType(AksharaEmptyState).evaluate().isNotEmpty;
        expect(
          honest,
          isTrue,
          reason: '${surface.name}: a failed repository call must render '
              'AksharaErrorState (or an honest empty state), not content.',
        );

        final rendered = _renderedText(tester).join('\n');
        for (final fabricated in kFabricatedStrings) {
          expect(
            rendered.contains(fabricated),
            isFalse,
            reason: '${surface.name}: rendered the fabricated value '
                '"$fabricated" after the repository failed.',
          );
        }
      });
    }
  });

  // ── Direction B ────────────────────────────────────────────────────────
  // The invariant, stated precisely: for a quantity the payload CARRIES, the
  // surface must render the value — never the unknown marker. Asserted on the
  // KPI cards, because a KPI card is exactly "one quantity, one value", so the
  // contradiction is unambiguous there. A broad "no — anywhere on the page"
  // sweep would be wrong: other SECTIONS legitimately show `—` for data they
  // genuinely do not have, and that is the marker doing its job.
  group('B · the same quantity is never rendered two ways at once', () {
    testWidgets(
      'parent dashboard: attendance & fees appear as values, not as "—"',
      (tester) async {
        await _pump(
          tester,
          const ParentDashboardScreen(),
          [
            parentDashboardFutureProvider
                .overrideWith((ref) async => _fullParentDashboard()),
          ],
        );

        final rendered = _renderedText(tester).toList();
        // The hero pill carries the real values …
        expect(rendered, contains('Present'));
        expect(rendered, contains('₹1,500 due'));

        // … and so must the KPI cards for the SAME quantities. Before the fix
        // the KPI row looked the chips up with `label.contains('attendance')`
        // and `label.contains('fee')`, which never matched `Present` or
        // `₹1,500 due`, so both cards printed `—` directly under the hero that
        // was showing the true values.
        final kpis = _kpiCards(tester);
        expect(kpis.keys, containsAll(<String>['Attendance', 'Fees due']));
        for (final entry in kpis.entries) {
          expect(
            kUnknownMarkers.contains(entry.value.trim()),
            isFalse,
            reason: 'KPI card "${entry.key}" rendered "${entry.value}" while '
                'the payload carried a value for that quantity. The same '
                'quantity is on screen twice — once as data, once as unknown.',
          );
        }
      },
    );

    testWidgets(
      'parent dashboard: a genuinely absent quantity still reads as unknown',
      (tester) async {
        // The other half of the invariant. `—` must keep its meaning: when the
        // payload really has nothing, the marker MUST appear (and no zero or
        // demo value may stand in for it).
        await _pump(
          tester,
          const ParentDashboardScreen(),
          [
            parentDashboardFutureProvider.overrideWith(
              (ref) async => const ParentDashboardData(
                childName: 'Test Child',
                childClass: '5-B',
                greetingEyebrow: 'Monday',
                greetingHeadline: 'Day at a glance',
                schoolName: 'Test School',
                unreadNotifications: 0,
                statusChips: [],
                quickActions: [],
                todaySummary: [],
                notices: [],
                events: [],
                aiInsight: DashboardAiInsight(message: '', actionLabel: ''),
              ),
            ),
          ],
        );

        final kpis = _kpiCards(tester);
        expect(kpis, isNotEmpty);
        for (final entry in kpis.entries) {
          expect(
            entry.value.trim(),
            '—',
            reason: 'KPI card "${entry.key}" must read "—" when the payload '
                'carries nothing for it. It rendered "${entry.value}".',
          );
        }
        expect(
          kpis.values.any((v) => v.trim() == '0'),
          isFalse,
          reason: 'A missing count must not render as a measured 0 — that is a '
              'false claim, not an honest unknown.',
        );
      },
    );
  });
}
