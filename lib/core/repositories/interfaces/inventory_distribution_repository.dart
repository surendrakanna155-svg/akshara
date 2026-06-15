import '../../../features/inventory_distribution/inventory_distribution_models.dart';
import '../../../features/phase5/phase5_models.dart';
import '../repository_query.dart';

abstract class InventoryDistributionRepository {
  Future<InvDistributionDashboard> getDashboard({required RepositoryQuery query});

  Future<List<InvCatalogItem>> listCatalog({
    required RepositoryQuery query,
    String? category,
  });

  Future<List<InvStudentDistribution>> listDistributions({
    required RepositoryQuery query,
    String? studentId,
    String? status,
  });

  Future<InvStudentDistribution> createDistribution({
    required RepositoryQuery query,
    required String studentId,
    required String catalogItemId,
    int quantity = 1,
  });

  Future<InvStudentDistribution> transitionStatus({
    required RepositoryQuery query,
    required String distributionId,
    required String status,
    String? notes,
  });

  Future<({InvStudentDistribution distribution, String? paymentRequestId})> requestReplacement({
    required RepositoryQuery query,
    required String distributionId,
    String? notes,
  });

  Future<InvDistributionReports> getReports({required RepositoryQuery query});

  Future<List<InvReplacementRequest>> listReplacementRequests({
    required RepositoryQuery query,
    String? status,
  });

  Future<InvReplacementRequest> approveReplacement({
    required RepositoryQuery query,
    required String requestId,
  });

  Future<InvReplacementRequest> fulfillReplacement({
    required RepositoryQuery query,
    required String requestId,
  });

  Future<InvReplacementRequest> rejectReplacement({
    required RepositoryQuery query,
    required String requestId,
    String? reason,
  });
}
