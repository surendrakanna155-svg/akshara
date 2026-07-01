import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

/// FIN-9 — head-wise outstanding dues (per fee head across open invoices).
final financeHeadWiseDuesFutureProvider =
    FutureProvider<List<HeadWiseDue>>((ref) async {
  return ref.read(financeRepositoryProvider).getHeadWiseDues(
        query: ref.watch(repositoryQueryProvider),
      );
});
