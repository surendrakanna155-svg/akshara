import 'package:akshara_erp/core/analytics/debug_analytics_service.dart';
import 'package:akshara_erp/core/analytics/noop_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoOpAnalyticsService is safe', () {
    const service = NoOpAnalyticsService();
    expect(() => service.logEvent('screen_view'), returnsNormally);
    expect(() => service.setUserId('user-1'), returnsNormally);
  });

  test('DebugAnalyticsService accepts calls', () {
    const service = DebugAnalyticsService();
    expect(() => service.logEvent('login', parameters: {'role': 'parent'}), returnsNormally);
  });
}
