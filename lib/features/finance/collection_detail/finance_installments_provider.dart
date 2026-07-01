import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

/// FIN-6 — the installment / term-wise due schedule for a single invoice.
/// Keyed by invoiceId; empty for an empty invoice id (no schedule to load).
final financeInvoiceInstallmentsFutureProvider =
    FutureProvider.family<List<InstallmentScheduleEntry>, String>(
  (ref, invoiceId) async {
    if (invoiceId.isEmpty) return const [];
    return ref.read(financeRepositoryProvider).getInvoiceInstallments(
          query: ref.watch(repositoryQueryProvider),
          invoiceId: invoiceId,
        );
  },
);
