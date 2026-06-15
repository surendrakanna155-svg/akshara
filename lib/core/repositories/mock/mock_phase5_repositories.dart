import '../../../features/phase5/phase5_models.dart';
import '../interfaces/phase5_repositories.dart';
import '../repository_query.dart';

class MockParentExperienceRepository implements ParentExperienceRepository {
  @override
  Future<ParentExperienceHub> getHub({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final isPriya = studentId == 'student_2';
    return ParentExperienceHub(
      studentId: studentId,
      overview: ParentExperienceOverview(
        childName: isPriya ? 'Priya Kumar' : 'Ravi Kumar',
        classLabel: isPriya ? 'Grade 5 · Section B' : 'Grade 8 · Section A',
        riskLevel: isPriya ? 'low' : 'medium',
        riskScore: isPriya ? 28 : 42,
        pendingInventoryAcks: isPriya ? 0 : 1,
        pendingPaymentRequests: isPriya ? 1 : 0,
      ),
      academics: const ParentExperienceAcademics(
        homeworkSubmitted: 12,
        homeworkTotal: 15,
        recentExams: [
          ParentExamSummary(title: 'Unit Test 1', avgPct: 78),
          ParentExamSummary(title: 'Mid Term', avgPct: 82),
        ],
      ),
      attendance: const ParentExperienceAttendance(
        present: 85,
        absent: 5,
        total: 90,
        pct: 94,
      ),
      inventory: const ParentExperienceInventory(
        issued: 2,
        pending: 1,
        items: [
          ParentInventoryItem(
            id: 'dist_1',
            itemName: 'Mathematics Textbook',
            category: 'books',
            status: 'parent_acknowledged',
            quantity: 1,
          ),
          ParentInventoryItem(
            id: 'dist_2',
            itemName: 'School Uniform Set',
            category: 'uniforms',
            status: 'distributed',
            quantity: 1,
          ),
        ],
      ),
      communication: const ParentExperienceCommunication(
        recentCount: 3,
        lastMessageAt: '2026-06-08',
      ),
      guidance: const ParentExperienceGuidance(
        available: true,
        summary: 'Weekly progress: attendance 94%, homework on track.',
        reports: [
          ParentGuidanceReport(
            mode: 'weekly',
            summary: 'Weekly progress: attendance 94%, homework on track.',
            createdAt: '2026-06-08',
          ),
          ParentGuidanceReport(
            mode: 'monthly',
            summary: 'Monthly review: strong in Science, needs Math practice.',
            createdAt: '2026-06-01',
          ),
          ParentGuidanceReport(
            mode: 'exam_review',
            summary: 'Exam review: focus revision on Algebra and Geometry.',
            createdAt: '2026-05-20',
          ),
        ],
      ),
      homeworkIntelligence: const ParentHomeworkIntelligence(
        weakTopics: ['Mathematics Unit Test (52%)', 'Science Mock (58%)'],
        suggestedRevision: [
          'Revise Mathematics Unit Test',
          'Revise Science Mock'
        ],
        teacherRecommendations: [
          'Complete 2 pending homework assignments',
          'Review teacher feedback on returned worksheets',
        ],
      ),
    );
  }

  @override
  Future<void> acknowledgeItem({
    required RepositoryQuery query,
    required String studentId,
    required String distributionId,
    required String acknowledgementType,
    String? notes,
  }) async {}
}

class MockEmployeeIntelligenceRepository
    implements EmployeeIntelligenceRepository {
  @override
  Future<Employee360Profile> getEmployee360({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    return Employee360Profile(
      profile: {
        'id': employeeId,
        'displayName': 'Priya Nair',
        'department': 'Science',
        'status': 'active',
      },
      roles: const [
        {'roleCode': 'teacher', 'isPrimary': true},
        {'roleCode': 'coordinator', 'isPrimary': false},
      ],
      workload: const EmployeeWorkload(
        workloadPercent: 72,
        burnoutRisk: 'medium',
        overloadScore: 58,
        substitutionLoad: 2,
        coordinatorLoad: 1,
      ),
      leave: const {'approved': 2, 'pending': 0},
      insights: const [
        'Strong classroom engagement',
        'Monitor substitution load'
      ],
    );
  }

  @override
  Future<EmployeeIntelligenceDashboard> getIntelligenceDashboard({
    required RepositoryQuery query,
  }) async {
    return const EmployeeIntelligenceDashboard(
      teachersNeedingSupport: [
        EmployeeInsightRow(
          employeeId: 'emp_3',
          name: 'Raj Kumar',
          burnoutRisk: 'high',
        ),
      ],
      highPerformers: [
        EmployeeInsightRow(employeeId: 'emp_1', name: 'Priya Nair', score: 88),
      ],
      workloadBalancing: [
        EmployeeWorkloadRow(
            employeeId: 'emp_3', name: 'Raj Kumar', workloadPercent: 91),
        EmployeeWorkloadRow(
            employeeId: 'emp_1', name: 'Priya Nair', workloadPercent: 72),
      ],
      avgWorkloadPercent: 68,
    );
  }
}

class MockOperationsHubRepository implements OperationsHubRepository {
  final List<OperationsAlert> _alerts = [
    const OperationsAlert(
      id: 'student-risk',
      module: 'intelligence',
      title: '2 high-risk students',
      severity: 'high',
    ),
    const OperationsAlert(
      id: 'fee-overdue',
      module: 'finance',
      title: '6 critical fee defaulters',
      severity: 'high',
    ),
  ];

  final List<OperationsAction> _actions = [
    const OperationsAction(
      id: 'inv-pending',
      module: 'inventory',
      title: '4 distributions pending',
    ),
    const OperationsAction(
      id: 'workflow-approvals',
      module: 'management',
      title: '3 workflow approvals pending',
    ),
  ];

  @override
  Future<OperationsHubSnapshot> getHub({required RepositoryQuery query}) async {
    return OperationsHubSnapshot(
      schoolHealth: 82,
      dailySummary: const OperationsDailySummary(
        attendancePct: 91,
        collectionsToday: 125000,
        communicationsToday: 5,
        criticalAlerts: 3,
      ),
      criticalAlerts: List<OperationsAlert>.unmodifiable(_alerts),
      pendingActions: List<OperationsAction>.unmodifiable(_actions),
      widgets: const OperationsWidgets(
        todayAttendance: {'present': 420, 'absent': 38, 'total': 458},
        todayCollections: {'amount': 125000, 'count': 18},
        todayCommunications: {'sent': 5, 'pending': 2},
        studentRiskAlerts: 2,
        employeeRiskAlerts: 1,
        inventoryAlerts: 4,
        feeAlerts: 6,
      ),
    );
  }

  @override
  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) async {
    _alerts.removeWhere((alert) => alert.id == alertId);
  }

  @override
  Future<void> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    _actions.removeWhere((action) => action.id == actionId);
  }
}

class MockSchoolMemoriesRepository implements SchoolMemoriesRepository {
  MockSchoolMemoriesRepository() {
    _events.addAll(const [
      SchoolMemoryEvent(
        id: 'evt_1',
        title: 'Annual Day 2026',
        category: 'annual_day',
        eventDate: '2026-03-15',
        status: 'published',
        description: 'Celebrating student achievements',
        albums: [
          SchoolMemoryAlbum(
            id: 'alb_1',
            title: 'Stage performances',
            mediaCount: 1,
            media: [
              SchoolMemoryMedia(
                id: 'med_1',
                title: 'Opening dance',
                mediaType: 'photo',
                storageUrl: 'https://picsum.photos/400/300',
                shareToken: 'share_demo_1',
              ),
            ],
          ),
        ],
      ),
      SchoolMemoryEvent(
        id: 'evt_2',
        title: 'Sports Day',
        category: 'sports_day',
        eventDate: '2026-01-20',
        status: 'published',
      ),
      SchoolMemoryEvent(
        id: 'evt_3',
        title: 'Graduation Preview',
        category: 'graduation',
        eventDate: '2026-06-20',
        status: 'draft',
        description: 'Draft curation for graduation highlights.',
      ),
    ]);
  }

  final List<SchoolMemoryEvent> _events = [];
  int _mediaSeq = 2;

  @override
  Future<List<SchoolMemoryEvent>> listEvents({
    required RepositoryQuery query,
    String? category,
  }) async {
    return _events
        .where((e) => category == null || e.category == category)
        .toList();
  }

  @override
  Future<SchoolMemoryEvent> createEvent({
    required RepositoryQuery query,
    required String title,
    required String category,
    String? description,
  }) async {
    final event = SchoolMemoryEvent(
      id: 'evt_new_${_events.length + 1}',
      title: title,
      category: category,
      eventDate: '2026-06-10',
      status: 'draft',
      description: description,
    );
    _events.add(event);
    return event;
  }

  @override
  Future<SchoolMemoryEvent> getEvent({
    required RepositoryQuery query,
    required String eventId,
  }) async {
    return _events.firstWhere((e) => e.id == eventId);
  }

  @override
  Future<SchoolMemoryEvent> publishEvent({
    required RepositoryQuery query,
    required String eventId,
  }) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index < 0) throw StateError('Event not found');
    final updated = SchoolMemoryEvent(
      id: _events[index].id,
      title: _events[index].title,
      category: _events[index].category,
      eventDate: _events[index].eventDate,
      status: 'published',
      description: _events[index].description,
      visibility: _events[index].visibility,
      albums: _events[index].albums,
    );
    _events[index] = updated;
    return updated;
  }

  @override
  Future<MemoryUploadPresign> presignUpload({
    required RepositoryQuery query,
    required String eventId,
    required String filename,
    String? albumId,
    String? albumTitle,
    String? mediaType,
  }) async {
    final resolvedAlbumId = albumId ?? 'alb_new_$eventId';
    return MemoryUploadPresign(
      albumId: resolvedAlbumId,
      signedUrl: 'https://storage.mock/upload/$filename',
      path: 'org/school/$eventId/$resolvedAlbumId/$filename',
      mediaType: mediaType ?? (filename.endsWith('.mp4') ? 'video' : 'photo'),
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
  }) async {
    final mediaId = 'med_${_mediaSeq++}';
    final shareToken = 'share_$mediaId';
    final media = SchoolMemoryMedia(
      id: mediaId,
      title: title,
      mediaType: mediaType ?? 'photo',
      storageUrl: 'https://storage.mock/$storagePath',
      shareToken: shareToken,
    );
    _appendMedia(eventId, albumId, media);
    return MemoryUploadConfirm(
      mediaId: mediaId,
      shareToken: shareToken,
      downloadUrl: 'https://storage.mock/download/$mediaId',
    );
  }

  @override
  Future<String> getDownloadUrl({
    required RepositoryQuery query,
    required String mediaId,
  }) async =>
      'https://storage.mock/download/$mediaId';

  @override
  Future<MemoryShareLink> resolveShareLink({
    required RepositoryQuery query,
    required String shareToken,
  }) async {
    for (final event in _events) {
      for (final album in event.albums) {
        for (final media in album.media) {
          if (media.shareToken == shareToken) {
            return MemoryShareLink(
              mediaId: media.id,
              eventId: event.id,
              downloadUrl: 'https://storage.mock/share/$shareToken',
            );
          }
        }
      }
    }
    throw StateError('Share token not found');
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
    );
    return confirmUpload(
      query: query,
      eventId: eventId,
      albumId: presign.albumId,
      storagePath: presign.path,
      title: title,
      mediaType: mediaType ?? presign.mediaType,
    );
  }

  void _appendMedia(String eventId, String albumId, SchoolMemoryMedia media) {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex < 0) return;
    final event = _events[eventIndex];
    final albums = List<SchoolMemoryAlbum>.from(event.albums);
    final albumIndex = albums.indexWhere((a) => a.id == albumId);
    if (albumIndex >= 0) {
      final album = albums[albumIndex];
      final mediaList = [...album.media, media];
      albums[albumIndex] = SchoolMemoryAlbum(
        id: album.id,
        title: album.title,
        mediaCount: mediaList.length,
        media: mediaList,
      );
    } else {
      albums.add(
        SchoolMemoryAlbum(
          id: albumId,
          title: 'New album',
          mediaCount: 1,
          media: [media],
        ),
      );
    }
    _events[eventIndex] = SchoolMemoryEvent(
      id: event.id,
      title: event.title,
      category: event.category,
      eventDate: event.eventDate,
      status: event.status,
      description: event.description,
      visibility: event.visibility,
      albums: albums,
    );
  }
}

class MockAchievementPromotionRepository
    implements AchievementPromotionRepository {
  final List<AchievementPromotion> _items = const [
    AchievementPromotion(
      id: 'promo_1',
      achievementType: 'gold_medal',
      title: 'Gold Medal — Science Olympiad',
      status: 'published',
      assets: {
        'poster': {
          'id': 'poster',
          'label': 'Poster',
          'headline': 'Celebrating Gold Medal — Science Olympiad',
          'caption': 'Official achievement poster',
          'format': 'image/png',
          'width': 1080,
          'height': 1920,
          'aspectRatio': '9:16',
        },
        'whatsapp': {
          'id': 'whatsapp',
          'label': 'WhatsApp Banner',
          'headline': 'Gold Medal — Science Olympiad',
          'caption': '🎉 Gold Medal — Science Olympiad!',
          'format': 'image/jpeg',
          'width': 1200,
          'height': 630,
        },
      },
      analytics: {'views': 120, 'shares': 34, 'downloads': 18},
    ),
  ];

  @override
  Future<List<AchievementPromotion>> listPromotions({
    required RepositoryQuery query,
    String? status,
  }) async {
    return _items.where((p) => status == null || p.status == status).toList();
  }

  @override
  Future<AchievementPromotion> createPromotion({
    required RepositoryQuery query,
    required String achievementType,
    required String title,
    String? description,
  }) async {
    return AchievementPromotion(
      id: 'promo_new',
      achievementType: achievementType,
      title: title,
      status: 'draft',
      assets: const {},
      analytics: const {'views': 0, 'shares': 0, 'downloads': 0},
      description: description,
    );
  }

  @override
  Future<AchievementPromotion> generateAssets({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    return AchievementPromotion(
      id: promotionId,
      achievementType: 'competition_winner',
      title: 'New Achievement',
      status: 'pending_approval',
      assets: {
        'poster': {
          'id': 'poster',
          'label': 'Poster',
          'headline': 'New Achievement',
          'caption': 'Generated poster metadata',
          'format': 'image/png',
          'width': 1080,
          'height': 1920,
        },
      },
      analytics: const {'views': 0, 'shares': 0, 'downloads': 0},
    );
  }

  @override
  Future<AchievementPromotion> approvePromotion({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    return AchievementPromotion(
      id: promotionId,
      achievementType: 'competition_winner',
      title: 'New Achievement',
      status: 'approved',
      assets: const {'poster': 'Generated poster'},
      analytics: const {'views': 0, 'shares': 0, 'downloads': 0},
    );
  }

  @override
  Future<AchievementPromotion> publishPromotion({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    return AchievementPromotion(
      id: promotionId,
      achievementType: 'competition_winner',
      title: 'New Achievement',
      status: 'published',
      assets: const {
        'poster': {
          'id': 'poster',
          'label': 'Poster',
          'headline': 'New Achievement',
          'caption': 'Generated poster metadata',
          'format': 'image/png',
          'width': 1080,
          'height': 1920,
        },
      },
      analytics: const {'views': 1, 'shares': 0, 'downloads': 0},
    );
  }

  @override
  Future<void> trackMetric({
    required RepositoryQuery query,
    required String promotionId,
    required String metric,
  }) async {}

  @override
  Future<AchievementPromotion> getPromotion({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    return _items.firstWhere((p) => p.id == promotionId);
  }
}
