import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_models.dart';

/// Offline cache for the resolved subscription, mirroring
/// [SchoolConfigurationStorage]. Keeps the last-known plan so a transient
/// backend outage never silently downgrades a live org to Trial.
const kSubscriptionStorageKey = 'akshara_subscription_v1';

class EntitlementStorage {
  EntitlementStorage(this._prefs);

  final SharedPreferences _prefs;

  ResolvedSubscription? readSync() {
    final raw = _prefs.getString(kSubscriptionStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ResolvedSubscription.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> write(ResolvedSubscription subscription) async {
    await _prefs.setString(
      kSubscriptionStorageKey,
      jsonEncode(subscription.toJson()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(kSubscriptionStorageKey);
  }
}
