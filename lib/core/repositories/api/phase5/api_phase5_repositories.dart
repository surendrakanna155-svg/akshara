import '../../../../features/phase5/phase5_models.dart';
import '../../interfaces/phase5_repositories.dart';
import '../../repository_query.dart';
import 'phase5_mapper.dart';
import 'phase5_remote_datasource.dart';

class ApiParentExperienceRepository implements ParentExperienceRepository {
  ApiParentExperienceRepository({required Phase5RemoteDataSource remote})
      : _remote = remote,
        _mapper = Phase5Mapper();

  final Phase5RemoteDataSource _remote;
  final Phase5Mapper _mapper;

  @override
  Future<ParentExperienceHub> getHub({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return _mapper.mapParentExperienceHub(
      await _remote.fetchParentExperienceHub(
          query: query, studentId: studentId),
    );
  }

  @override
  Future<void> acknowledgeItem({
    required RepositoryQuery query,
    required String studentId,
    required String distributionId,
    required String acknowledgementType,
    String? notes,
  }) async {
    await _remote.acknowledgeParentItem(
      query: query,
      body: {
        'studentId': studentId,
        'distributionId': distributionId,
        'acknowledgementType': acknowledgementType,
        if (notes != null) 'notes': notes,
      },
    );
  }
}

class ApiEmployeeIntelligenceRepository
    implements EmployeeIntelligenceRepository {
  ApiEmployeeIntelligenceRepository({required Phase5RemoteDataSource remote})
      : _remote = remote,
        _mapper = Phase5Mapper();

  final Phase5RemoteDataSource _remote;
  final Phase5Mapper _mapper;

  @override
  Future<Employee360Profile> getEmployee360({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    return _mapper.mapEmployee360(
      await _remote.fetchEmployee360(query: query, employeeId: employeeId),
    );
  }

  @override
  Future<EmployeeIntelligenceDashboard> getIntelligenceDashboard({
    required RepositoryQuery query,
  }) async {
    return _mapper.mapEmployeeIntelligenceDashboard(
      await _remote.fetchEmployeeIntelligenceDashboard(query: query),
    );
  }
}

class ApiOperationsHubRepository implements OperationsHubRepository {
  ApiOperationsHubRepository({required Phase5RemoteDataSource remote})
      : _remote = remote,
        _mapper = Phase5Mapper();

  final Phase5RemoteDataSource _remote;
  final Phase5Mapper _mapper;

  @override
  Future<OperationsHubSnapshot> getHub({required RepositoryQuery query}) async {
    return _mapper
        .mapOperationsHub(await _remote.fetchOperationsHub(query: query));
  }

  @override
  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) async {
    await _remote.dismissOperationsAlert(query: query, alertId: alertId);
  }

  @override
  Future<void> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    await _remote.completeOperationsAction(query: query, actionId: actionId);
  }
}

class ApiSchoolMemoriesRepository implements SchoolMemoriesRepository {
  ApiSchoolMemoriesRepository({required Phase5RemoteDataSource remote})
      : _remote = remote,
        _mapper = Phase5Mapper();

  final Phase5RemoteDataSource _remote;
  final Phase5Mapper _mapper;

  @override
  Future<List<SchoolMemoryEvent>> listEvents({
    required RepositoryQuery query,
    String? category,
  }) async {
    final items =
        await _remote.fetchMemoryEvents(query: query, category: category);
    return items.map(_mapper.mapMemoryEvent).toList();
  }

  @override
  Future<SchoolMemoryEvent> getEvent({
    required RepositoryQuery query,
    required String eventId,
  }) async {
    return _mapper.mapMemoryEvent(
      await _remote.fetchMemoryEvent(query: query, eventId: eventId),
    );
  }

  @override
  Future<SchoolMemoryEvent> createEvent({
    required RepositoryQuery query,
    required String title,
    required String category,
    String? description,
  }) async {
    return _mapper.mapMemoryEvent(
      await _remote.createMemoryEvent(
        query: query,
        body: {
          'title': title,
          'category': category,
          if (description != null) 'description': description,
        },
      ),
    );
  }

  @override
  Future<SchoolMemoryEvent> publishEvent({
    required RepositoryQuery query,
    required String eventId,
  }) async {
    await _remote.publishMemoryEvent(query: query, eventId: eventId);
    return getEvent(query: query, eventId: eventId);
  }

  @override
  Future<MemoryUploadPresign> presignUpload({
    required RepositoryQuery query,
    required String eventId,
    required String filename,
    String? albumId,
    String? albumTitle,
    String? mediaType,
    int? sizeBytes,
  }) async {
    return _mapper.mapMemoryUploadPresign(
      await _remote.presignMemoryUpload(
        query: query,
        eventId: eventId,
        body: {
          'filename': filename,
          if (albumId != null) 'albumId': albumId,
          if (albumTitle != null) 'albumTitle': albumTitle,
          if (mediaType != null) 'mediaType': mediaType,
          // PRC-A Batch 4 — declare the size at PRESIGN so the server storage-quota
          // gate can reject an over-quota upload BEFORE the bytes are stored
          // (blocking at confirm is too late). Same value used for confirm recording.
          if (sizeBytes != null) 'sizeBytes': sizeBytes,
        },
      ),
    );
  }

  @override
  Future<MemoryUploadConfirm> confirmUpload({
    required RepositoryQuery query,
    required String eventId,
    required String albumId,
    required String storagePath,
    required String title,
    String? mediaType,
    int? sizeBytes,
  }) async {
    return _mapper.mapMemoryUploadConfirm(
      await _remote.confirmMemoryUpload(
        query: query,
        eventId: eventId,
        body: {
          'albumId': albumId,
          'storagePath': storagePath,
          'title': title,
          if (mediaType != null) 'mediaType': mediaType,
          if (sizeBytes != null) 'sizeBytes': sizeBytes,
        },
      ),
    );
  }

  @override
  Future<String> getDownloadUrl({
    required RepositoryQuery query,
    required String mediaId,
  }) async {
    final data =
        await _remote.fetchMemoryDownloadUrl(query: query, mediaId: mediaId);
    return data['downloadUrl'] as String? ?? '';
  }

  @override
  Future<MemoryShareLink> resolveShareLink({
    required RepositoryQuery query,
    required String shareToken,
  }) async {
    return _mapper.mapMemoryShareLink(
      await _remote.fetchMemoryShareLink(query: query, shareToken: shareToken),
    );
  }

  @override
  Future<MemoryUploadConfirm> uploadMediaBytes({
    required RepositoryQuery query,
    required String eventId,
    required List<int> bytes,
    required String filename,
    required String title,
    String? albumId,
    String? albumTitle,
    String? mediaType,
  }) async {
    final presign = await presignUpload(
      query: query,
      eventId: eventId,
      filename: filename,
      albumId: albumId,
      albumTitle: albumTitle,
      mediaType: mediaType,
      sizeBytes: bytes.length,
    );
    final contentType = (mediaType ?? presign.mediaType) == 'video'
        ? 'video/mp4'
        : 'image/jpeg';
    await _remote.putSignedUpload(
      signedUrl: presign.signedUrl,
      bytes: bytes,
      contentType: contentType,
    );
    return confirmUpload(
      query: query,
      eventId: eventId,
      albumId: presign.albumId,
      storagePath: presign.path,
      title: title,
      mediaType: mediaType ?? presign.mediaType,
      sizeBytes: bytes.length,
    );
  }
}

class ApiAchievementPromotionRepository
    implements AchievementPromotionRepository {
  ApiAchievementPromotionRepository({required Phase5RemoteDataSource remote})
      : _remote = remote,
        _mapper = Phase5Mapper();

  final Phase5RemoteDataSource _remote;
  final Phase5Mapper _mapper;

  @override
  Future<List<AchievementPromotion>> listPromotions({
    required RepositoryQuery query,
    String? status,
  }) async {
    final items = await _remote.fetchPromotions(query: query, status: status);
    return items.map(_mapper.mapPromotion).toList();
  }

  @override
  Future<AchievementPromotion> createPromotion({
    required RepositoryQuery query,
    required String achievementType,
    required String title,
    String? description,
  }) async {
    return _mapper.mapPromotion(
      await _remote.createPromotion(
        query: query,
        body: {
          'achievementType': achievementType,
          'title': title,
          if (description != null) 'description': description,
        },
      ),
    );
  }

  @override
  Future<AchievementPromotion> generateAssets({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    return _mapper.mapPromotion(
      await _remote.generatePromotionAssets(
          query: query, promotionId: promotionId),
    );
  }

  @override
  Future<AchievementPromotion> approvePromotion({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    return _mapper.mapPromotion(
      await _remote.approvePromotion(query: query, promotionId: promotionId),
    );
  }

  @override
  Future<AchievementPromotion> publishPromotion({
    required RepositoryQuery query,
    required String promotionId,
    List<String> destinations = const [],
  }) async {
    return _mapper.mapPromotion(
      await _remote.publishPromotion(
        query: query,
        promotionId: promotionId,
        destinations: destinations,
      ),
    );
  }

  @override
  Future<void> trackMetric({
    required RepositoryQuery query,
    required String promotionId,
    required String metric,
  }) async {
    await _remote.trackPromotionMetric(
      query: query,
      promotionId: promotionId,
      metric: metric,
    );
  }

  @override
  Future<AchievementPromotion> getPromotion({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    final items = await listPromotions(query: query);
    return items.firstWhere((p) => p.id == promotionId);
  }
}
