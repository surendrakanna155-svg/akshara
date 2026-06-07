/// Performance profiling registry for provider rebuild optimization (v4.7).
library;

/// Describes a provider cluster targeted for rebuild reduction.
class ProviderClusterDescriptor {
  const ProviderClusterDescriptor({
    required this.module,
    required this.cluster,
    required this.watchCount,
    required this.optimized,
    required this.technique,
  });

  final String module;
  final String cluster;
  final int watchCount;
  final bool optimized;
  final String technique;
}

/// v4.7 optimization targets across ERP modules.
const List<ProviderClusterDescriptor> kProviderOptimizationClusters = [
  ProviderClusterDescriptor(
    module: 'finance',
    cluster: 'dashboard',
    watchCount: 3,
    optimized: true,
    technique: 'ViewState + handoff decouple',
  ),
  ProviderClusterDescriptor(
    module: 'finance',
    cluster: 'collections',
    watchCount: 6,
    optimized: true,
    technique: 'PaginatedResult + scoped queries',
  ),
  ProviderClusterDescriptor(
    module: 'admissions',
    cluster: 'fee_handoff',
    watchCount: 4,
    optimized: true,
    technique: 'Override map decoupled from async fetch',
  ),
  ProviderClusterDescriptor(
    module: 'admissions',
    cluster: 'dashboard',
    watchCount: 2,
    optimized: true,
    technique: 'ViewState pattern',
  ),
  ProviderClusterDescriptor(
    module: 'sis',
    cluster: 'dashboard',
    watchCount: 3,
    optimized: true,
    technique: 'ViewState pattern',
  ),
  ProviderClusterDescriptor(
    module: 'control_center',
    cluster: 'dashboard',
    watchCount: 5,
    optimized: false,
    technique: 'Legacy triad — migrate v4.9',
  ),
  ProviderClusterDescriptor(
    module: 'management',
    cluster: 'dashboard',
    watchCount: 5,
    optimized: false,
    technique: 'Legacy triad — migrate v4.9',
  ),
  ProviderClusterDescriptor(
    module: 'hr',
    cluster: 'dashboard',
    watchCount: 5,
    optimized: false,
    technique: 'Legacy triad — migrate v4.9',
  ),
  ProviderClusterDescriptor(
    module: 'parent',
    cluster: 'dashboard',
    watchCount: 3,
    optimized: true,
    technique: 'FutureProvider cache (Riverpod default)',
  ),
  ProviderClusterDescriptor(
    module: 'teacher',
    cluster: 'dashboard',
    watchCount: 2,
    optimized: true,
    technique: 'FutureProvider cache (Riverpod default)',
  ),
];

int get optimizedClusterCount =>
    kProviderOptimizationClusters.where((c) => c.optimized).length;

int get totalClusterWatchCount => kProviderOptimizationClusters
    .map((c) => c.watchCount)
    .fold(0, (a, b) => a + b);

int get optimizedWatchReductionEstimate =>
    kProviderOptimizationClusters.where((c) => c.optimized).length * 2;
