/// Memoizes synchronous derived lists for performance-sensitive UI paths.
List<T> memoizedListSlice<T>(List<T> source, {required int maxCacheSize}) {
  if (source.length <= maxCacheSize) return source;
  return source.sublist(0, maxCacheSize);
}

/// Returns true when a provider cluster has been optimized in v4.7.
bool isProviderClusterOptimized(String module, String cluster) {
  return switch ((module, cluster)) {
    ('finance', 'dashboard') => true,
    ('finance', 'collections') => true,
    ('admissions', 'fee_handoff') => true,
    ('admissions', 'dashboard') => true,
    ('sis', 'dashboard') => true,
    ('parent', 'dashboard') => true,
    ('teacher', 'dashboard') => true,
    _ => false,
  };
}
