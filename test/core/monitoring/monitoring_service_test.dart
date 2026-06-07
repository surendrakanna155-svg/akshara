import 'package:akshara_erp/core/monitoring/debug_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/noop_monitoring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoOpMonitoringService records nothing', () {
    const service = NoOpMonitoringService();
    expect(() => service.recordError(Exception('test')), returnsNormally);
    expect(() => service.recordEvent('test'), returnsNormally);
    expect(() => service.recordMetric('latency', 1.0), returnsNormally);
  });

  test('DebugMonitoringService accepts calls', () {
    const service = DebugMonitoringService();
    expect(() => service.recordError(Exception('test'), context: 'unit'), returnsNormally);
    expect(() => service.recordEvent('app.start'), returnsNormally);
  });
}
