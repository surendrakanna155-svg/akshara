import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_security_providers.dart';
import 'auth_token_models.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageBackendProvider));
});

/// Active API tokens for the current session (null when anonymous).
final authTokensProvider = Provider<AuthTokens?>((ref) {
  return ref.watch(tokenStorageProvider).readSync();
});

/// Persists refreshed tokens from the auth interceptor.
final onTokensRefreshedProvider = Provider<void Function(AuthTokens)?>((ref) {
  return (tokens) {
    ref.read(tokenStorageProvider).write(tokens);
  };
});

/// Eagerly loads tokens from secure storage into the in-memory cache.
final tokenStorageLoaderProvider = FutureProvider<void>((ref) async {
  await ref.read(tokenStorageProvider).read();
});
