import '../model/draft_record.dart';
import '../store/reliability_store.dart';
import 'draft_model.dart';

/// Saves and recovers in-progress form drafts for the current user.
///
/// A screen calls [save] (debounced and/or on app background) while editing,
/// then [recover] on open to offer "Resume / Discard". Drafts are deleted on a
/// confirmed submit (or explicit discard) and wiped on logout via the store.
class DraftController {
  DraftController(
    this._store, {
    required this.userId,
    this.schoolId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReliabilityStore _store;
  final String userId;
  final String? schoolId;
  final DateTime Function() _clock;

  Future<void> save(DraftModel model) {
    return _store.putDraft(
      DraftRecord(
        key: model.draftKey,
        userId: userId,
        schoolId: schoolId,
        json: model.toJson(),
        label: model.draftLabel,
        updatedAt: _clock(),
      ),
    );
  }

  Future<DraftRecord?> recover(String draftKey) => _store.getDraft(draftKey);

  Future<bool> hasDraft(String draftKey) async =>
      (await _store.getDraft(draftKey)) != null;

  Future<void> discard(String draftKey) => _store.deleteDraft(draftKey);

  Future<List<DraftRecord>> myDrafts() => _store.draftsForUser(userId);
}
