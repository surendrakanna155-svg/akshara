import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/errors/error_observer.dart';
import 'core/errors/error_reporting_service.dart';
import 'core/errors/global_error_handler.dart';
import 'core/exams/exam_administration_persistence.dart';
import 'core/exams/exam_administration_store.dart';
import 'core/notifications/push_messaging_service.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/reliability/reliability_providers.dart';
import 'core/reliability/store/reliability_store_opener.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // PERF-4 (F1): cold-start instrumentation. Measures process-entry → first
  // rendered frame so the <3s budget can be verified on a real device with
  // `flutter run --profile` (look for "cold-start: Nms" in the log). Disabled in
  // release builds to avoid log noise / overhead.
  final coldStart = kReleaseMode ? null : (Stopwatch()..start());
  final binding = WidgetsFlutterBinding.ensureInitialized();
  if (coldStart != null) {
    binding.addPostFrameCallback((_) {
      coldStart.stop();
      debugPrint('cold-start: ${coldStart.elapsedMilliseconds}ms '
          '(process-entry → first frame)');
    });
  }
  final prefs = await SharedPreferences.getInstance();
  // PRA-P1-13: bind durable storage to the exam administration store at startup
  // so the per-school grading scale (and published results) SURVIVE a cold
  // restart. Previously attachPersistence was wired only in tests, so in prod
  // `_persist()` early-returned and the grading scale reset to Standard on every
  // launch. Must run BEFORE the exam settings provider first triggers
  // ensureSeeded() (which loads the persisted snapshot).
  ExamAdministrationStore.instance
      .attachPersistence(ExamAdministrationPersistence(prefs));
  // Data Reliability Platform: open the durable, encrypted on-device store for
  // drafts + the outbox once, and bind it so every write inherits offline-safe
  // queue/retry and draft persistence (Phase 0b).
  final reliabilityStoreOpen = await openReliabilityStore();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    reliabilityStoreProvider.overrideWithValue(reliabilityStoreOpen.store),
    // REL-8: make a non-durable fallback (encrypted-DB open failed) observable
    // instead of silent, so the Sync Center can warn that work won't survive a
    // restart this session.
    reliabilityStoreDegradedProvider
        .overrideWithValue(reliabilityStoreOpen.degraded),
  ];

  final bootstrap = ProviderContainer(overrides: overrides);
  final errorReporting = bootstrap.read(errorReportingServiceProvider);
  GlobalErrorHandler(errorReporting).install();
  bootstrap.dispose();

  final container = ProviderContainer(
    overrides: overrides,
    observers: [AksharaErrorObserver(errorReporting)],
  );

  // Initialize Firebase Cloud Messaging. Guarded so a device without Google
  // Play services (or any init error) still launches the app normally.
  final firebaseReady = await _initFirebase();

  await runGuardedZone(errorReporting, () async {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const AksharaApp(),
      ),
    );
    if (firebaseReady) {
      // Start the push layer after the first frame so the router + messenger
      // are mounted before any deep-link navigation or banner.
      unawaited(container.read(pushMessagingServiceProvider).start());
    }
    // Start the sync engine so any writes queued while offline drain
    // automatically on reconnect (with idempotent, exactly-once replay).
    container.read(syncEngineProvider);
  });
}

/// Initializes Firebase + registers the background message handler. Returns
/// false (without throwing) when Firebase is unavailable so the caller can skip
/// the push layer gracefully.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return true;
  } catch (error) {
    if (!kReleaseMode) debugPrint('Firebase initialization skipped: $error');
    return false;
  }
}
