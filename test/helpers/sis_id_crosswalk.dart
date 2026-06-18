/// Mock SIS student codes mapped to staging UUIDs for API-mode crosswalk tests.
class SisIdCrosswalk {
  const SisIdCrosswalk._();

  /// Canonical probe student used across pilot fixtures.
  static const probeUuid = 'a4000000-0000-4000-8000-000000000001';

  /// Primary mock registry id → staging UUID.
  static const Map<String, String> mockToUuid = {
    'SIS-STU-10421': probeUuid,
    'STU-001': probeUuid,
  };

  /// Resolves a mock or server identifier to canonical UUID when known.
  static String? resolveToUuid(String idOrCode) {
    if (mockToUuid.containsKey(idOrCode)) {
      return mockToUuid[idOrCode];
    }
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (uuidPattern.hasMatch(idOrCode)) return idOrCode;
    return null;
  }

  /// Returns mock id when staging UUID is the probe student.
  static String? mockIdForUuid(String uuid) {
    for (final entry in mockToUuid.entries) {
      if (entry.value == uuid) return entry.key;
    }
    return null;
  }
}
