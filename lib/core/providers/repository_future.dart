import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderSkipped extends Error {}

T? watchRepositoryFuture<T>(
  Ref ref,
  AsyncValue<T> async, {
  required bool manualLoading,
  required bool manualError,
  required bool manualEmpty,
}) {
  if (manualLoading || manualError || manualEmpty) return null;
  return async.whenOrNull(data: (d) => d);
}
