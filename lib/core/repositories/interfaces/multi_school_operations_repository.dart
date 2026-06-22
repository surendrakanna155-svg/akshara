import '../../../features/platform/multi_school/multi_school_models.dart';
import '../repository_query.dart';

abstract class MultiSchoolOperationsRepository {
  Future<SchoolPortfolioDashboard> getPortfolioDashboard({
    required RepositoryQuery query,
  });

  Future<List<SchoolLifecycleRecord>> listSchools({
    required RepositoryQuery query,
    SchoolLifecycleStatus? status,
  });

  Future<SchoolHealthScore> getSchoolHealth({
    required RepositoryQuery query,
    required String schoolId,
  });

  Future<SchoolOnboardingDraft> createOnboardingDraft({
    required RepositoryQuery query,
    required SchoolOnboardingDraft draft,
  });

  Future<SchoolLifecycleRecord> submitOnboarding({
    required RepositoryQuery query,
    required String draftId,
  });

  Future<SchoolLifecycleRecord> activateSchool({
    required RepositoryQuery query,
    required String schoolId,
  });

  Future<SchoolLifecycleRecord> deactivateSchool({
    required RepositoryQuery query,
    required String schoolId,
    String? reason,
  });

  Future<List<PortfolioAlert>> listAlerts({
    required RepositoryQuery query,
  });

  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  });

  Future<List<PortfolioAction>> listPendingActions({
    required RepositoryQuery query,
  });

  Future<PortfolioAction> completeAction({
    required RepositoryQuery query,
    required String actionId,
  });
}
