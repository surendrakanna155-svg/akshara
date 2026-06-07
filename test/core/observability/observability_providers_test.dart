import 'package:akshara_erp/core/observability/operational_metrics_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operational metrics registry has core metrics', () {
    expect(operationalMetricCount, greaterThanOrEqualTo(8));
    expect(
      kOperationalMetrics.map((m) => m.id),
      contains('audit.queue.pending_count'),
    );
  });
}
