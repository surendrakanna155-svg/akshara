import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/draft_record.dart';
import 'draft_controller.dart';
import 'draft_model.dart';
import 'draft_providers.dart';

/// Holds every on-screen form autosaver currently alive so the app's lifecycle
/// observer can flush them all in one shot when the app is backgrounded, locked
/// or killed — the "never lose a half-typed form" guarantee (design §5).
class DraftFlushRegistry {
  final Set<Future<void> Function()> _flushers = <Future<void> Function()>{};

  void add(Future<void> Function() flush) => _flushers.add(flush);
  void remove(Future<void> Function() flush) => _flushers.remove(flush);

  /// Flush every registered form immediately (called on app background/detach).
  Future<void> flushAll() async {
    for (final Future<void> Function() flush in List.of(_flushers)) {
      try {
        await flush();
      } catch (_) {
        // One form failing to persist must not stop the others.
      }
    }
  }
}

final Provider<DraftFlushRegistry> draftFlushRegistryProvider =
    Provider<DraftFlushRegistry>((_) => DraftFlushRegistry());

/// Drop-in autosave + recovery for a draftable form screen.
///
/// A screen `State` mixes this in, implements [buildDraftSnapshot], calls
/// [scheduleDraftSave] whenever the form changes, [offerResumeIfAny] on first
/// build, and [discardDraftOnSubmit] after a confirmed submit. Autosave is
/// debounced; the latest snapshot is also flushed when the app is backgrounded
/// (via [DraftFlushRegistry]) so work survives a phone-lock / app-switch / kill.
mixin DraftAutosaveMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _debounce;
  Future<void> Function()? _registered;
  // Cached at initState so dispose never calls `ref` after teardown
  // (Riverpod forbids reading a disposed ConsumerState's ref).
  DraftFlushRegistry? _registry;
  bool _resumeOffered = false;

  /// Debounce window before an idle form autosaves.
  Duration get autosaveDebounce => const Duration(milliseconds: 800);

  DraftController get draftController => ref.read(draftControllerProvider);

  /// The form's current snapshot, or null when there is nothing worth saving
  /// (e.g. an untouched / empty form).
  DraftModel? buildDraftSnapshot();

  @override
  void initState() {
    super.initState();
    _registry = ref.read(draftFlushRegistryProvider);
    _registered = flushDraftNow;
    _registry!.add(_registered!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final Future<void> Function()? registered = _registered;
    if (registered != null) {
      _registry?.remove(registered);
    }
    super.dispose();
  }

  /// Schedule a debounced autosave; call this from form `onChanged` handlers.
  void scheduleDraftSave() {
    _debounce?.cancel();
    _debounce = Timer(autosaveDebounce, () {
      unawaited(flushDraftNow());
    });
  }

  /// Persist the current snapshot immediately (debounce cancelled).
  Future<void> flushDraftNow() async {
    _debounce?.cancel();
    final DraftModel? snapshot = buildDraftSnapshot();
    if (snapshot == null) return;
    await draftController.save(snapshot);
  }

  /// Delete the persisted draft for [draftKey] — call after a confirmed submit
  /// or an explicit discard so a completed form is never re-offered.
  Future<void> discardDraftOnSubmit(String draftKey) {
    _debounce?.cancel();
    return draftController.discard(draftKey);
  }

  /// On first build, if a recoverable draft exists for [draftKey], show a
  /// non-blocking "Resume / Discard" banner (WhatsApp-draft UX). [onResume]
  /// receives the saved form JSON to rehydrate the screen.
  Future<void> offerResumeIfAny({
    required String draftKey,
    required void Function(Map<String, dynamic> json) onResume,
  }) async {
    if (_resumeOffered) return;
    _resumeOffered = true;
    final DraftRecord? record = await draftController.recover(draftKey);
    if (record == null || !mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(record.label == null
            ? 'You have an unsaved draft. Resume where you left off?'
            : 'Unsaved draft: ${record.label}. Resume where you left off?'),
        leading: const Icon(Icons.history),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              unawaited(discardDraftOnSubmit(draftKey));
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              onResume(record.json);
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}
