import '../../../features/phase5/phase5_models.dart';
import '../repository_query.dart';

abstract class ParentExperienceRepository {
  Future<ParentExperienceHub> getHub({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<void> acknowledgeItem({
    required RepositoryQuery query,
    required String studentId,
    required String distributionId,
    required String acknowledgementType,
    String? notes,
  });
}

abstract class EmployeeIntelligenceRepository {
  Future<Employee360Profile> getEmployee360({
    required RepositoryQuery query,
    required String employeeId,
  });

  Future<EmployeeIntelligenceDashboard> getIntelligenceDashboard({
    required RepositoryQuery query,
  });
}

abstract class OperationsHubRepository {
  Future<OperationsHubSnapshot> getHub({required RepositoryQuery query});

  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  });

  Future<void> completeAction({
    required RepositoryQuery query,
    required String actionId,
  });
}

abstract class SchoolMemoriesRepository {
  Future<List<SchoolMemoryEvent>> listEvents({
    required RepositoryQuery query,
    String? category,
  });

  Future<SchoolMemoryEvent> getEvent({
    required RepositoryQuery query,
    required String eventId,
  });

  Future<SchoolMemoryEvent> createEvent({
    required RepositoryQuery query,
    required String title,
    required String category,
    String? description,
  });

  Future<SchoolMemoryEvent> publishEvent({
    required RepositoryQuery query,
    required String eventId,
  });

  Future<MemoryUploadPresign> presignUpload({
    required RepositoryQuery query,
    required String eventId,
    required String filename,
    String? albumId,
    String? albumTitle,
    String? mediaType,
  });

  Future<MemoryUploadConfirm> confirmUpload({
    required RepositoryQuery query,
    required String eventId,
    required String albumId,
    required String storagePath,
    required String title,
    String? mediaType,
  });

  Future<String> getDownloadUrl({
    required RepositoryQuery query,
    required String mediaId,
  });

  Future<MemoryShareLink> resolveShareLink({
    required RepositoryQuery query,
    required String shareToken,
  });

  /// Presign → PUT bytes → confirm.
  Future<MemoryUploadConfirm> uploadMediaBytes({
    required RepositoryQuery query,
    required String eventId,
    required List<int> bytes,
    required String filename,
    required String title,
    String? albumId,
    String? albumTitle,
    String? mediaType,
  });
}

abstract class AchievementPromotionRepository {
  Future<List<AchievementPromotion>> listPromotions({
    required RepositoryQuery query,
    String? status,
  });

  Future<AchievementPromotion> createPromotion({
    required RepositoryQuery query,
    required String achievementType,
    required String title,
    String? description,
  });

  Future<AchievementPromotion> generateAssets({
    required RepositoryQuery query,
    required String promotionId,
  });

  Future<AchievementPromotion> approvePromotion({
    required RepositoryQuery query,
    required String promotionId,
  });

  Future<AchievementPromotion> publishPromotion({
    required RepositoryQuery query,
    required String promotionId,
  });

  Future<void> trackMetric({
    required RepositoryQuery query,
    required String promotionId,
    required String metric,
  });

  Future<AchievementPromotion> getPromotion({
    required RepositoryQuery query,
    required String promotionId,
  });
}
