/// Implemented by any form that participates in draft persistence. The platform
/// machinery (autosave + recovery) is generic; a form only declares its key and
/// how to serialise/restore itself.
abstract interface class DraftModel {
  /// Stable, entity-scoped key, e.g. `exam_marks:{examId}:{classId}`.
  String get draftKey;

  /// Optional human-readable label for the resume prompt / Sync Center.
  String? get draftLabel;

  /// Serialise the in-progress form state.
  Map<String, dynamic> toJson();
}

/// A ready-made [DraftModel] for forms that already produce a JSON snapshot
/// (e.g. an immutable `…Draft` state model with its own `toJson`). The screen
/// supplies the entity-scoped [draftKey] (it knows the entity context, like the
/// child / class / exam id) and the snapshot — no per-form boilerplate.
class MapDraft implements DraftModel {
  const MapDraft(this.draftKey, this._json, {this.draftLabel});

  @override
  final String draftKey;

  @override
  final String? draftLabel;

  final Map<String, dynamic> _json;

  @override
  Map<String, dynamic> toJson() => _json;
}
