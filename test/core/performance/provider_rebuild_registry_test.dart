import 'package:akshara_erp/core/performance/provider_rebuild_registry.dart';
import 'package:akshara_erp/core/performance/repository_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4.7 provider optimization registry has targets', () {
    expect(kProviderOptimizationClusters, isNotEmpty);
    expect(optimizedClusterCount, greaterThanOrEqualTo(6));
  });

  test('fee handoff cluster marked optimized', () {
    expect(isProviderClusterOptimized('admissions', 'fee_handoff'), isTrue);
  });

  test('memoizedListSlice caps large lists', () {
    final source = List.generate(100, (i) => i);
    final slice = memoizedListSlice(source, maxCacheSize: 20);
    expect(slice.length, 20);
    expect(slice.first, 0);
  });
}
