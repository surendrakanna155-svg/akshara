import 'package:akshara_erp/core/reliability/drafts/draft_controller.dart';
import 'package:akshara_erp/core/reliability/drafts/draft_model.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Draft persistence (design §5) — "resume exactly where you left off". A
/// half-filled leave form is autosaved, survives to the next session, and is
/// restored byte-for-byte; submitting/discarding clears it. Closes QA-X-005/009.
void main() {
  test('a half-typed leave form is saved and resumed across sessions', () async {
    final store = InMemoryReliabilityStore();

    // Session 1: the parent fills part of the form, then the app is closed.
    final draft = const LeaveApplyDraft().copyWith(
      fromDateLabel: '2026-07-01',
      reason: 'Family wedding out of town',
      type: LeaveType.family,
    );
    final controller =
        DraftController(store, userId: 'user-1', schoolId: 'school-1');
    await controller.save(
      MapDraft('leave_apply:child-1', draft.toJson(), draftLabel: 'Leave'),
    );

    // Session 2: a fresh controller (same durable store) recovers the draft.
    final next = DraftController(store, userId: 'user-1', schoolId: 'school-1');
    final recovered = await next.recover('leave_apply:child-1');
    expect(recovered, isNotNull);
    final restored = LeaveApplyDraft.fromJson(recovered!.json);
    expect(restored.fromDateLabel, '2026-07-01');
    expect(restored.reason, 'Family wedding out of town');
    expect(restored.type, LeaveType.family);

    // Submitting/discarding clears it so it is never re-offered.
    await next.discard('leave_apply:child-1');
    expect(await next.recover('leave_apply:child-1'), isNull);
  });

  test('drafts are private per user and wiped on logout', () async {
    final store = InMemoryReliabilityStore();
    final mine = DraftController(store, userId: 'user-1');
    await mine.save(const MapDraft('k', <String, dynamic>{'v': 1}));

    // Another user on the same device sees none of user-1's drafts.
    final other = DraftController(store, userId: 'user-2');
    expect(await other.myDrafts(), isEmpty);
    expect(await mine.myDrafts(), hasLength(1));

    // Logout wipes everything (multi-user device safety, §9).
    await store.clear();
    expect(await mine.myDrafts(), isEmpty);
  });
}
