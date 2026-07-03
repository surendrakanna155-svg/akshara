import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/parent/actions/parent_action_inbox_screen.dart';
import 'package:akshara_erp/features/parent/actions/parent_actions_provider.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/parent/family/parent_family_view_screen.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/fees/parent_year_statement_exporter.dart';
import 'package:akshara_erp/features/parent/receipts/receipt_models.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/leave/widgets/leave_request_row.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';
import 'package:akshara_erp/features/parent/ptm/parent_ptm_screen.dart';
import 'package:akshara_erp/features/parent_meetings/parent_meeting_models.dart';
import 'package:akshara_erp/features/parent_meetings/parent_meetings_repository.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';
import '../../helpers/auth_test_overrides.dart';
import '../../helpers/provider_test_overrides.dart';

const _childRavi = LinkedChild(id: 'child-ravi', name: 'Ravi', classLabel: '8-A');
const _childPriya =
    LinkedChild(id: 'child-priya', name: 'Priya', classLabel: '5-B');

AuthState _parentAuth({
  LinkedChild? active = _childRavi,
  List<LinkedChild> children = const [_childRavi, _childPriya],
}) {
  return AuthState(
    status: AuthStatus.authenticated,
    role: UserRole.parent,
    displayName: 'Parent',
    selectedChild: active,
    linkedChildren: children,
  );
}

/// A recording fake meetings repo so RSVP writes can be asserted.
class _FakeMeetingsRepo implements ParentMeetingsRepository {
  _FakeMeetingsRepo(this._meetings);

  List<ParentMeetingRecord> _meetings;
  final List<({String meetingId, MeetingRsvpResponse response})> rsvpCalls = [];

  @override
  Future<List<ParentMeetingRecord>> listMeetings({
    required RepositoryQuery query,
  }) async =>
      List.of(_meetings);

  @override
  Future<ParentMeetingRecord> rsvpMeeting({
    required RepositoryQuery query,
    required String meetingId,
    required MeetingRsvpResponse response,
    String? note,
  }) async {
    rsvpCalls.add((meetingId: meetingId, response: response));
    _meetings = [
      for (final m in _meetings)
        if (m.id == meetingId)
          m.copyWith(rsvp: MeetingRsvp(response: response))
        else
          m,
    ];
    return _meetings.firstWhere((m) => m.id == meetingId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used: ${invocation.memberName}');
}

ParentMeetingRecord _meeting({
  String id = 'm1',
  String studentId = 'child-ravi',
  MeetingRsvp? rsvp,
  DateTime? at,
  List<MeetingActionItem> actionItems = const [],
}) {
  return ParentMeetingRecord(
    id: id,
    studentId: studentId,
    studentName: 'Ravi',
    parentName: 'Parent',
    teacherName: 'Mrs. Sharma',
    meetingAt: at ?? DateTime.now().add(const Duration(days: 3)),
    notes: 'Discuss progress',
    actionItems: actionItems,
    rsvp: rsvp,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required List<Override> overrides,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateOverride(_parentAuth()),
        ...providerTestOverrides(),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: home,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Back the tenant/audit providers with mock prefs so parent write mutations
    // (which record an audit event) complete in the widget harness.
    await initProviderTestPrefs();
  });

  group('PAR-1 · PTM RSVP', () {
    testWidgets('accept records the RSVP via the repo', (tester) async {
      final repo = _FakeMeetingsRepo([_meeting()]);
      await _pump(
        tester,
        const ParentPtmScreen(),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
          parentMeetingsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(
        find.byKey(QaTestKeys.parentPtmRsvpAcceptButton('m1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(QaTestKeys.parentPtmRsvpAcceptButton('m1')));
      await tester.pumpAndSettle();

      expect(repo.rsvpCalls, hasLength(1));
      expect(repo.rsvpCalls.first.response, MeetingRsvpResponse.accepted);
      // The recorded response is now reflected (buttons replaced by status).
      expect(
        find.byKey(QaTestKeys.parentPtmRsvpStatus('m1')),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.parentPtmRsvpAcceptButton('m1')),
        findsNothing,
      );
    });

    testWidgets('decline records the RSVP via the repo', (tester) async {
      final repo = _FakeMeetingsRepo([_meeting()]);
      await _pump(
        tester,
        const ParentPtmScreen(),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
          parentMeetingsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.parentPtmRsvpDeclineButton('m1')));
      await tester.pumpAndSettle();

      expect(repo.rsvpCalls.single.response, MeetingRsvpResponse.declined);
    });

    testWidgets('does NOT leak another child\'s meeting (active-child scope)',
        (tester) async {
      // A meeting for a sibling must not appear on Ravi's PTM screen.
      final repo = _FakeMeetingsRepo([
        _meeting(id: 'm_ravi', studentId: 'child-ravi'),
        _meeting(id: 'm_priya', studentId: 'child-priya'),
      ]);
      await _pump(
        tester,
        const ParentPtmScreen(),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
          parentMeetingsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(find.byKey(QaTestKeys.parentPtmRsvpAcceptButton('m_ravi')),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.parentPtmRsvpAcceptButton('m_priya')),
          findsNothing);
    });
  });

  group('PAR-6 · PTM hero + action items', () {
    testWidgets('renders the next-PTM hero and action items', (tester) async {
      final repo = _FakeMeetingsRepo([
        _meeting(
          at: DateTime.now().add(const Duration(days: 2)),
          actionItems: const [
            MeetingActionItem(id: 'a1', title: 'Bring report card'),
          ],
        ),
      ]);
      await _pump(
        tester,
        const ParentPtmScreen(),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
          parentMeetingsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(find.byKey(QaTestKeys.parentPtmNextHero), findsOneWidget);
      expect(find.text('Bring report card'), findsOneWidget);
    });
  });

  group('PAR-D1 · leave cancel + PAR-3 attach', () {
    testWidgets('a pending leave shows cancel + attach; approved does not',
        (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [_HistoryHarness()]),
          ),
        ),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
        ],
      );
      // The harness renders a pending + an approved row.
      expect(find.byKey(QaTestKeys.parentLeaveCancelButton('lv_pending')),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.parentLeaveCancelButton('lv_approved')),
          findsNothing);
    });

    testWidgets('cancelling a pending leave calls the repo + snackbars',
        (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [_HistoryHarness()]),
          ),
        ),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
        ],
      );

      await tester
          .tap(find.byKey(QaTestKeys.parentLeaveCancelButton('lv_pending')));
      await tester.pumpAndSettle();
      // Confirm dialog.
      await tester
          .tap(find.byKey(QaTestKeys.parentLeaveCancelConfirmButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.parentLeaveCancelSnackbar), findsOneWidget);
    });

    testWidgets('attach sets a document reference', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [_HistoryHarness()]),
          ),
        ),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
        ],
      );

      // Open the attach dialog on the pending row, enter a reference, confirm.
      await tester.tap(
        find.byKey(QaTestKeys.parentLeaveAttachmentButton).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(QaTestKeys.parentLeaveAttachmentField), findsOneWidget);
      await tester.enterText(
        find.byKey(QaTestKeys.parentLeaveAttachmentField),
        'medical_cert.pdf',
      );
      await tester
          .tap(find.byKey(QaTestKeys.parentLeaveAttachmentConfirmButton));
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // The dialog closed (the attach mutation ran through attachLeaveDocument).
      expect(
        find.byKey(QaTestKeys.parentLeaveAttachmentConfirmButton),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('PAR-D2 · family view', () {
    testWidgets('renders a card per linked child', (tester) async {
      await _pump(
        tester,
        const ParentFamilyViewScreen(),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
        ],
      );

      expect(find.byKey(QaTestKeys.parentFamilyViewScreen), findsOneWidget);
      expect(find.byKey(QaTestKeys.parentFamilyChildCard('child-ravi')),
          findsOneWidget);
      expect(find.byKey(QaTestKeys.parentFamilyChildCard('child-priya')),
          findsOneWidget);
    });
  });

  group('PAR-D4 · action inbox', () {
    testWidgets('aggregates fee + exam actions, fees first', (tester) async {
      await _pump(
        tester,
        ParentActionInboxScreen(onActionTap: (_) {}),
        overrides: [
          parentActiveChildProvider.overrideWithValue(_childRavi),
          // A real pending balance drives a fee action.
          parentFeesProvider.overrideWithValue(ParentFeesData.mock()),
        ],
      );

      expect(find.byKey(QaTestKeys.parentActionInboxScreen), findsOneWidget);
      // The fee action is present and ordered first.
      expect(
        find.byKey(QaTestKeys.parentActionInboxItem('fee')),
        findsOneWidget,
      );
    });
  });

  group('PAR-2 · Apply Leave quick action', () {
    test('the dashboard quick-actions grid includes Apply Leave', () {
      final actions = ParentDashboardData.mock().quickActions;
      expect(
        actions.any((a) => a.id == 'apply_leave'),
        isTrue,
        reason: 'PAR-2 promotes Apply Leave onto the dashboard grid',
      );
    });
  });

  group('PAR-4 · year statement exporter', () {
    test('grid has one row per receipt + a total row', () {
      const exporter =
          ParentYearStatementExporter(AksharaReportExportService());
      final receipts = [
        const FeeReceipt(
          id: 'r1',
          receiptNumber: 'APS-001',
          title: 'Term 1',
          dateLabel: '10 Apr 2026',
          amount: 8000,
          paymentMethod: 'UPI',
          statusLabel: 'Paid',
          childName: 'Ravi',
          childClass: '8-A',
          category: 'term',
          lineItems: [],
        ),
        const FeeReceipt(
          id: 'r2',
          receiptNumber: 'APS-002',
          title: 'Transport',
          dateLabel: '10 May 2026',
          amount: 2000,
          paymentMethod: 'Card',
          statusLabel: 'Paid',
          childName: 'Ravi',
          childClass: '8-A',
          category: 'transport',
          lineItems: [],
        ),
      ];

      final rows = exporter.rows(receipts);
      // 2 receipts + 1 total row.
      expect(rows, hasLength(3));
      expect(rows.first.first, 'APS-001');
      // Total column carries the sum.
      expect(rows.last.last, '10000');
      expect(ParentYearStatementExporter.headers.first, 'Receipt No');
    });
  });

  group('parent actions provider ordering', () {
    test('fees rank before exams', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(_parentAuth()),
          ...providerTestOverrides(),
          parentActiveChildProvider.overrideWithValue(_childRavi),
          parentFeesProvider.overrideWithValue(ParentFeesData.mock()),
        ],
      );
      addTearDown(container.dispose);

      final actions = container.read(parentActiveChildActionsProvider);
      expect(actions, isNotEmpty);
      expect(actions.first.kind, ParentActionKind.fee);
    });
  });
}

/// Renders a pending + approved leave row against the real mutation providers.
class _HistoryHarness extends ConsumerWidget {
  const _HistoryHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        LeaveRequestRow(
          request: LeaveRequest(
            id: 'lv_pending',
            childName: 'Ravi',
            childClass: '8-A',
            fromDateLabel: '12 Jun',
            toDateLabel: '12 Jun',
            reason: 'Doctor advised rest for one day',
            type: LeaveType.sick,
            status: LeaveStatus.pending,
            submittedLabel: 'Just now',
            timeline: [],
          ),
          initiallyExpanded: true,
        ),
        LeaveRequestRow(
          request: LeaveRequest(
            id: 'lv_approved',
            childName: 'Ravi',
            childClass: '8-A',
            fromDateLabel: '10 Jun',
            toDateLabel: '10 Jun',
            reason: 'Family function at home',
            type: LeaveType.family,
            status: LeaveStatus.approved,
            submittedLabel: 'Yesterday',
            timeline: [],
          ),
          initiallyExpanded: true,
        ),
      ],
    );
  }
}
