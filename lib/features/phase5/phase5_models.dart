/// Phase 5 domain models (v9.8–v10.3).
library;

class ParentExperienceHub {
  const ParentExperienceHub({
    required this.studentId,
    required this.overview,
    required this.academics,
    required this.attendance,
    required this.inventory,
    required this.communication,
    required this.guidance,
    required this.homeworkIntelligence,
  });

  final String studentId;
  final ParentExperienceOverview overview;
  final ParentExperienceAcademics academics;
  final ParentExperienceAttendance attendance;
  final ParentExperienceInventory inventory;
  final ParentExperienceCommunication communication;
  final ParentExperienceGuidance guidance;
  final ParentHomeworkIntelligence homeworkIntelligence;
}

class ParentExperienceOverview {
  const ParentExperienceOverview({
    required this.childName,
    required this.classLabel,
    required this.riskLevel,
    required this.riskScore,
    required this.pendingInventoryAcks,
    required this.pendingPaymentRequests,
  });

  final String childName;
  final String classLabel;
  final String riskLevel;
  final int riskScore;
  final int pendingInventoryAcks;
  final int pendingPaymentRequests;
}

class ParentExperienceAcademics {
  const ParentExperienceAcademics({
    required this.homeworkSubmitted,
    required this.homeworkTotal,
    required this.recentExams,
  });

  final int homeworkSubmitted;
  final int homeworkTotal;
  final List<ParentExamSummary> recentExams;
}

class ParentExamSummary {
  const ParentExamSummary({required this.title, required this.avgPct});
  final String title;
  final int avgPct;
}

class ParentExperienceAttendance {
  const ParentExperienceAttendance({
    required this.present,
    required this.absent,
    required this.total,
    required this.pct,
  });

  final int present;
  final int absent;
  final int total;
  final int pct;
}

class ParentExperienceInventory {
  const ParentExperienceInventory({
    required this.issued,
    required this.pending,
    required this.items,
  });

  final int issued;
  final int pending;
  final List<ParentInventoryItem> items;
}

class ParentInventoryItem {
  const ParentInventoryItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.status,
    required this.quantity,
  });

  final String id;
  final String itemName;
  final String category;
  final String status;
  final int quantity;
}

class ParentExperienceCommunication {
  const ParentExperienceCommunication({
    required this.recentCount,
    required this.lastMessageAt,
  });

  final int recentCount;
  final String? lastMessageAt;
}

class ParentExperienceGuidance {
  const ParentExperienceGuidance({
    required this.available,
    required this.summary,
    required this.reports,
  });

  final bool available;
  final String? summary;
  final List<ParentGuidanceReport> reports;
}

class ParentGuidanceReport {
  const ParentGuidanceReport({
    required this.mode,
    required this.summary,
    required this.createdAt,
  });

  final String mode;
  final String summary;
  final String createdAt;
}

class ParentHomeworkIntelligence {
  const ParentHomeworkIntelligence({
    required this.weakTopics,
    required this.suggestedRevision,
    required this.teacherRecommendations,
  });

  final List<String> weakTopics;
  final List<String> suggestedRevision;
  final List<String> teacherRecommendations;
}

class Employee360Profile {
  const Employee360Profile({
    required this.profile,
    required this.roles,
    required this.workload,
    required this.leave,
    required this.insights,
  });

  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> roles;
  final EmployeeWorkload workload;
  final Map<String, dynamic> leave;
  final List<String> insights;
}

class EmployeeWorkload {
  const EmployeeWorkload({
    required this.workloadPercent,
    required this.burnoutRisk,
    required this.overloadScore,
    required this.substitutionLoad,
    required this.coordinatorLoad,
  });

  final int workloadPercent;
  final String burnoutRisk;
  final int overloadScore;
  final int substitutionLoad;
  final int coordinatorLoad;
}

class EmployeeIntelligenceDashboard {
  const EmployeeIntelligenceDashboard({
    required this.teachersNeedingSupport,
    required this.highPerformers,
    required this.workloadBalancing,
    required this.avgWorkloadPercent,
  });

  final List<EmployeeInsightRow> teachersNeedingSupport;
  final List<EmployeeInsightRow> highPerformers;
  final List<EmployeeWorkloadRow> workloadBalancing;
  final int avgWorkloadPercent;
}

class EmployeeInsightRow {
  const EmployeeInsightRow({
    required this.employeeId,
    required this.name,
    this.burnoutRisk,
    this.score,
  });

  final String employeeId;
  final String name;
  final String? burnoutRisk;
  final int? score;
}

class EmployeeWorkloadRow {
  const EmployeeWorkloadRow({
    required this.employeeId,
    required this.name,
    required this.workloadPercent,
  });

  final String employeeId;
  final String name;
  final int workloadPercent;
}

class OperationsHubSnapshot {
  const OperationsHubSnapshot({
    required this.schoolHealth,
    required this.dailySummary,
    required this.criticalAlerts,
    required this.pendingActions,
    required this.widgets,
  });

  final int schoolHealth;
  final OperationsDailySummary dailySummary;
  final List<OperationsAlert> criticalAlerts;
  final List<OperationsAction> pendingActions;
  final OperationsWidgets widgets;
}

class OperationsDailySummary {
  const OperationsDailySummary({
    required this.attendancePct,
    required this.collectionsToday,
    required this.communicationsToday,
    required this.criticalAlerts,
  });

  final int attendancePct;
  final double collectionsToday;
  final int communicationsToday;
  final int criticalAlerts;
}

class OperationsAlert {
  const OperationsAlert({
    required this.id,
    required this.module,
    required this.title,
    required this.severity,
  });

  final String id;
  final String module;
  final String title;
  final String severity;
}

class OperationsAction {
  const OperationsAction({
    required this.id,
    required this.module,
    required this.title,
  });

  final String id;
  final String module;
  final String title;
}

class OperationsWidgets {
  const OperationsWidgets({
    required this.todayAttendance,
    required this.todayCollections,
    required this.todayCommunications,
    required this.studentRiskAlerts,
    required this.employeeRiskAlerts,
    required this.inventoryAlerts,
    required this.feeAlerts,
  });

  final Map<String, int> todayAttendance;
  final Map<String, num> todayCollections;
  final Map<String, int> todayCommunications;
  final int studentRiskAlerts;
  final int employeeRiskAlerts;
  final int inventoryAlerts;
  final int feeAlerts;
}

class InvDistributionReports {
  const InvDistributionReports({
    required this.pending,
    required this.issued,
    required this.replacement,
    required this.lost,
    required this.damaged,
    required this.byKitCategory,
  });

  final int pending;
  final int issued;
  final int replacement;
  final int lost;
  final int damaged;
  final List<InvKitCategoryReport> byKitCategory;
}

class InvKitCategoryReport {
  const InvKitCategoryReport({
    required this.category,
    required this.pending,
    required this.issued,
  });

  final String category;
  final int pending;
  final int issued;
}

class SchoolMemoryEvent {
  const SchoolMemoryEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.eventDate,
    required this.status,
    this.description,
    this.visibility,
    this.albums = const [],
  });

  final String id;
  final String title;
  final String category;
  final String eventDate;
  final String status;
  final String? description;
  final String? visibility;
  final List<SchoolMemoryAlbum> albums;
}

class SchoolMemoryAlbum {
  const SchoolMemoryAlbum({
    required this.id,
    required this.title,
    required this.mediaCount,
    this.media = const [],
  });

  final String id;
  final String title;
  final int mediaCount;
  final List<SchoolMemoryMedia> media;
}

class SchoolMemoryMedia {
  const SchoolMemoryMedia({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.storageUrl,
    this.thumbnailUrl,
    this.shareToken,
  });

  final String id;
  final String title;
  final String mediaType;
  final String storageUrl;
  final String? thumbnailUrl;
  final String? shareToken;

  bool get isVideo => mediaType == 'video' || mediaType.startsWith('video/');
}

class MemoryUploadPresign {
  const MemoryUploadPresign({
    required this.albumId,
    required this.signedUrl,
    required this.path,
    required this.mediaType,
  });

  final String albumId;
  final String signedUrl;
  final String path;
  final String mediaType;
}

class MemoryUploadConfirm {
  const MemoryUploadConfirm({
    required this.mediaId,
    required this.shareToken,
    required this.downloadUrl,
  });

  final String mediaId;
  final String shareToken;
  final String downloadUrl;
}

class MemoryShareLink {
  const MemoryShareLink({
    required this.mediaId,
    required this.eventId,
    required this.downloadUrl,
  });

  final String mediaId;
  final String eventId;
  final String downloadUrl;
}

class AchievementPromotion {
  const AchievementPromotion({
    required this.id,
    required this.achievementType,
    required this.title,
    required this.status,
    required this.assets,
    required this.analytics,
    this.description,
  });

  final String id;
  final String achievementType;
  final String title;
  final String status;
  final Map<String, dynamic> assets;
  final Map<String, int> analytics;
  final String? description;

  List<PromotionAssetPreview> get assetPreviews {
    return assets.entries
        .where((e) => e.value is Map)
        .map((e) => PromotionAssetPreview.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList();
  }
}

class PromotionAssetPreview {
  const PromotionAssetPreview({
    required this.id,
    required this.label,
    required this.headline,
    required this.caption,
    required this.format,
    this.width,
    this.height,
    this.aspectRatio,
    this.previewUrl,
  });

  factory PromotionAssetPreview.fromJson(String id, Map<String, dynamic> json) {
    return PromotionAssetPreview(
      id: id,
      label: json['label'] as String? ?? id,
      headline: json['headline'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      format: json['format'] as String? ?? 'text/plain',
      width: json['width'] as int?,
      height: json['height'] as int?,
      aspectRatio: json['aspectRatio'] as String?,
      previewUrl: json['previewUrl'] as String?,
    );
  }

  final String id;
  final String label;
  final String headline;
  final String caption;
  final String format;
  final int? width;
  final int? height;
  final String? aspectRatio;
  final String? previewUrl;

  Map<String, dynamic> toExportJson() => {
        'id': id,
        'label': label,
        'headline': headline,
        'caption': caption,
        'format': format,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (aspectRatio != null) 'aspectRatio': aspectRatio,
        if (previewUrl != null) 'previewUrl': previewUrl,
      };
}

/// Future image-generation hook — no AI implementation in v10.4.1.
abstract class PromotionImageGenerator {
  Future<String?> generatePoster({
    required String title,
    required String headline,
    required String caption,
    required int width,
    required int height,
  });
}
