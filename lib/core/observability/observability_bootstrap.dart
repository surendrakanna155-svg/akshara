import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'observability_providers.dart';

/// Initializes observability services based on environment flags.
///
/// Call from app startup after [ProviderScope] is available.
void bootstrapObservability(WidgetRef ref) {
  final config = ref.read(observabilityConfigProvider);
  if (kDebugMode && config.enableMonitoring) {
    ref.read(monitoringServiceProvider).recordEvent(
          'observability.bootstrap',
          properties: {'monitoring': '${config.enableMonitoring}'},
        );
  }
}
