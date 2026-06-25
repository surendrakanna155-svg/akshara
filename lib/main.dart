import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/errors/error_observer.dart';
import 'core/errors/error_reporting_service.dart';
import 'core/errors/global_error_handler.dart';
import 'core/notifications/push_messaging_service.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
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
    debugPrint('Firebase initialization skipped: $error');
    return false;
  }
}
