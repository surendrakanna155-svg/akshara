import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

class DebugAnalyticsService implements AnalyticsService {
  const DebugAnalyticsService();

  @override
  void logEvent(String name, {Map<String, String>? parameters}) {
    debugPrint('[Analytics] event=$name params=$parameters');
  }

  @override
  void setUserProperty(String name, String value) {
    debugPrint('[Analytics] userProperty $name=$value');
  }

  @override
  void setUserId(String? userId) {
    debugPrint('[Analytics] userId=$userId');
  }
}
