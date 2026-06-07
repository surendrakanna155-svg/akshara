import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/errors/error_observer.dart';
import 'core/errors/error_reporting_service.dart';
import 'core/errors/global_error_handler.dart';
import 'core/providers/shared_preferences_provider.dart';

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

  await runGuardedZone(errorReporting, () async {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const AksharaApp(),
      ),
    );
  });
}
