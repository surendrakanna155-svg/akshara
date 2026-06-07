import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selects a slice from [AsyncValue] data to reduce widget rebuild scope.
T? selectAsyncData<T, S>(
  AsyncValue<S> async,
  T? Function(S data) selector,
) {
  return async.whenOrNull(data: selector);
}
