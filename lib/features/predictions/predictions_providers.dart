import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'predictions_models.dart';

/// Advanced AI Predictions (B9) — read providers for the three prediction feeds.

final predictionsCanViewProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewFinance) ||
      rbac.hasPermission(Permission.viewAdmissions) ||
      rbac.hasPermission(Permission.viewStudentRisk);
});

final predictionsCanViewFeeDefaultProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewFinance);
});

final predictionsCanViewConversionProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewAdmissions);
});

final predictionsCanViewStudentRiskProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewStudentRisk);
});

final feeDefaultPredictionsProvider =
    FutureProvider<PredictionFeed<FeeDefaultPrediction>>((ref) async {
  return ref.read(predictionsRepositoryProvider).getFeeDefaultRisk(
        query: ref.watch(repositoryQueryProvider),
      );
});

final admissionConversionPredictionsProvider =
    FutureProvider<PredictionFeed<AdmissionConversionPrediction>>((ref) async {
  return ref.read(predictionsRepositoryProvider).getAdmissionConversion(
        query: ref.watch(repositoryQueryProvider),
      );
});

final studentRiskPredictionsProvider =
    FutureProvider<PredictionFeed<StudentRiskPrediction>>((ref) async {
  return ref.read(predictionsRepositoryProvider).getStudentRisk(
        query: ref.watch(repositoryQueryProvider),
      );
});
