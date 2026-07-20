import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import 'certificate_desk_datasource.dart';
import 'certificate_desk_models.dart';

final certificateDeskDataSourceProvider = Provider<CertificateDeskDataSource>(
  (ref) => CertificateDeskDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// The active status filter for the staff queue (null = all statuses).
final certificateRequestStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// The certificate request queue, refetched whenever the status filter changes.
final certificateRequestsProvider = FutureProvider.autoDispose<List<CertificateRequest>>((ref) {
  final status = ref.watch(certificateRequestStatusFilterProvider);
  return ref.watch(certificateDeskDataSourceProvider).list(status: status);
});
