import 'api_exception.dart';

/// Routes API writes to mock implementations when backend endpoints are not live.
Future<T> withMockWriteFallback<T>({
  required Future<T> Function() apiCall,
  required Future<T> Function() mockCall,
}) async {
  try {
    return await apiCall();
  } on ApiNotConnectedException {
    return mockCall();
  }
}
