import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'environment.dart';

/// Active deployment environment (override in tests or via dart-define).
final environmentProvider = Provider<Environment>((ref) {
  return Environment.fromDartDefine();
});

/// Whether any API repository may be activated (master switch).
final enableApiModeProvider = Provider<bool>((ref) {
  return ref.watch(environmentProvider).enableApiMode;
});
