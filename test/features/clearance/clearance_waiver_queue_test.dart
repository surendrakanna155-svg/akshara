// SCE-1 final audit — the checker's waiver queue: shows WHOSE exit (student
// name), pending → Approve/Reject, approved → Revoke, and surfaces the server's
// typed verdict (e.g. SELF_APPROVE_DENIED) as a message while refreshing.

import 'package:akshara_erp/features/clearance/clearance_datasource.dart';
import 'package:akshara_erp/features/clearance/clearance_models.dart';
import 'package:akshara_erp/features/clearance/clearance_providers.dart';
import 'package:akshara_erp/features/clearance/widgets/clearance_waiver_queue_dialog.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource implements ClearanceDataSource {
  _FakeDataSource(this._queue, {this.decideThrows});
  final List<ClearanceWaiver> _queue;
  final ClearanceWaiverRejected? decideThrows;
  final List<String> decided = [];
  final List<String> revoked = [];

  @override
  Future<List<ClearanceWaiver>> pendingWaivers() async => _queue;

  @override
  Future<ClearanceWaiver> decideWaiver({required String waiverId, required bool approve}) async {
    if (decideThrows != null) throw decideThrows!;
    decided.add(waiverId);
    return _queue.firstWhere((w) => w.id == waiverId);
  }

  @override
  Future<ClearanceWaiver> revokeWaiver({required String waiverId}) async {
    revoked.add(waiverId);
    return _queue.firstWhere((w) => w.id == waiverId);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

ClearanceWaiver _waiver({required String id, required String status, String? name}) => ClearanceWaiver(
      id: id,
      studentId: 's-$id',
      studentName: name,
      lifecycle: 'transfer_certificate',
      reason: 'small balance',
      amount: 300,
      status: status,
      makerId: 'm1',
    );

Future<_FakeDataSource> _pump(WidgetTester tester, _FakeDataSource ds) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clearanceDataSourceProvider.overrideWithValue(ds)],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: ClearanceWaiverQueueDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ds;
}

void main() {
  testWidgets('a pending waiver shows the STUDENT NAME + Approve/Reject (checker not blind)', (tester) async {
    final ds = await _pump(tester, _FakeDataSource([_waiver(id: 'w1', status: 'pending', name: 'Asha Rao')]));
    expect(find.byKey(const Key('clearance-waiver-student-w1')), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.byKey(const Key('clearance-waiver-approve-w1')), findsOneWidget);
    expect(find.byKey(const Key('clearance-waiver-reject-w1')), findsOneWidget);
    expect(find.byKey(const Key('clearance-waiver-revoke-w1')), findsNothing);

    await tester.tap(find.byKey(const Key('clearance-waiver-approve-w1')));
    await tester.pump();
    expect(ds.decided, ['w1']);
  });

  testWidgets('an approved-but-unconsumed waiver shows ONLY Revoke (the deadlock escape)', (tester) async {
    final ds = await _pump(tester, _FakeDataSource([_waiver(id: 'w2', status: 'approved', name: 'Ravi K')]));
    expect(find.byKey(const Key('clearance-waiver-revoke-w2')), findsOneWidget);
    expect(find.byKey(const Key('clearance-waiver-approve-w2')), findsNothing);
    await tester.tap(find.byKey(const Key('clearance-waiver-revoke-w2')));
    await tester.pump();
    expect(ds.revoked, ['w2']);
  });

  testWidgets('a SoD rejection surfaces the server message (not swallowed)', (tester) async {
    final ds = _FakeDataSource(
      [_waiver(id: 'w3', status: 'pending', name: 'Meena')],
      decideThrows: const ClearanceWaiverRejected(
        'CLEARANCE_WAIVER_SELF_APPROVE_DENIED',
        'You cannot approve a waiver you raised',
      ),
    );
    await _pump(tester, ds);
    await tester.tap(find.byKey(const Key('clearance-waiver-approve-w3')));
    await tester.pump();
    expect(find.text('You cannot approve a waiver you raised'), findsOneWidget);
  });

  testWidgets('an empty queue shows the empty state', (tester) async {
    await _pump(tester, _FakeDataSource(const []));
    expect(find.byKey(const Key('clearance-waiver-queue-empty')), findsOneWidget);
  });
}
