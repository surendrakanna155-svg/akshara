import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// BUS-008 — the mock write-fallback is a DEBUG/PROFILE affordance only.
///
/// It previously applied in every build: on [ApiNotConnectedException] the
/// wrapper silently ran the MOCK implementation and returned a success object,
/// so the UI showed "Stops updated" and the admin believed their data had
/// persisted when nothing had been written.
///
/// The catch is narrow (one exception type), so the blast radius was limited —
/// but a production data layer that can substitute fake writes for real ones is
/// precisely how a module reaches the state the Bus Tracking audit found: green
/// tests, confident screens, and code paths never once exercised end-to-end. It
/// also makes every subsequent verification untrustworthy, which is fatal to a
/// roadmap whose completion rule is "verified end-to-end or it isn't done".
///
/// In release builds an unreachable API now surfaces the real error to the
/// caller and persists nothing.
bool get _mockWriteFallbackAllowed => kDebugMode || kProfileMode;

/// Routes API writes to mock implementations when backend endpoints are not
/// live — **debug/profile builds only** (see [_mockWriteFallbackAllowed]).
Future<T> withMockWriteFallback<T>({
  required Future<T> Function() apiCall,
  required Future<T> Function() mockCall,
}) async {
  try {
    return await apiCall();
  } on ApiNotConnectedException {
    if (!_mockWriteFallbackAllowed) {
      // Release: fail loudly. A write that did not reach the backend must never
      // be reported to the user as a success.
      rethrow;
    }
    return mockCall();
  }
}
