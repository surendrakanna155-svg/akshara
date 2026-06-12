import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'environment.dart';

/// Active deployment environment (override in tests or via dart-define).
final environmentProvider = Provider<Environment>((ref) {
  return Environment.fromDartDefine();
});

/// Whether explicit demo/testing auth is enabled (local dev only unless dart-define).
final isDemoAuthEnabledProvider = Provider<bool>((ref) {
  return !ref.watch(environmentProvider).disableDemoAuth;
});

/// Whether any API repository may be activated (master switch).
final enableApiModeProvider = Provider<bool>((ref) {
  return ref.watch(environmentProvider).enableApiMode;
});
