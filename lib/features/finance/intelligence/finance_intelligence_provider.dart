import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'finance_intelligence_models.dart';

final financeCopilotProvider = FutureProvider<FinanceCopilotData>((ref) async {
  return ref.read(financeRepositoryProvider).getFinanceCopilot(
        query: ref.watch(repositoryQueryProvider),
      );
});

final financeExecutiveProvider = FutureProvider<FinanceExecutiveData>((ref) async {
  return ref.read(financeRepositoryProvider).getFinanceExecutiveDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});
