import '../../../../features/phase5/phase5_models.dart';

class Phase5Mapper {
  ParentExperienceHub mapParentExperienceHub(Map<String, dynamic> json) {
    final overview = json['overview'] as Map<String, dynamic>? ?? const {};
    final academics = json['academics'] as Map<String, dynamic>? ?? const {};
    final attendance = json['attendance'] as Map<String, dynamic>? ?? const {};
    final inventory = json['inventory'] as Map<String, dynamic>? ?? const {};
    final communication = json['communication'] as Map<String, dynamic>? ?? const {};
    final guidance = json['guidance'] as Map<String, dynamic>? ?? const {};
    final homeworkIntel = json['homeworkIntelligence'] as Map<String, dynamic>? ?? const {};
    final exams = academics['recentExams'] as List<dynamic>? ?? const [];
    final guidanceReports = guidance['reports'] as List<dynamic>? ?? const [];

    return ParentExperienceHub(
      studentId: json['studentId'] as String? ?? '',
      overview: ParentExperienceOverview(
        childName: overview['childName'] as String? ?? '',
        classLabel: overview['classLabel'] as String? ?? '',
        riskLevel: overview['riskLevel'] as String? ?? 'unknown',
        riskScore: overview['riskScore'] as int? ?? 0,
        pendingInventoryAcks: overview['pendingInventoryAcks'] as int? ?? 0,
        pendingPaymentRequests: overview['pendingPaymentRequests'] as int? ?? 0,
      ),
      academics: ParentExperienceAcademics(
        homeworkSubmitted: academics['homeworkSubmitted'] as int? ?? 0,
        homeworkTotal: academics['homeworkTotal'] as int? ?? 0,
        recentExams: exams
            .map(
              (e) => ParentExamSummary(
                title: (e as Map)['title'] as String? ?? (e)['examTitle'] as String? ?? '',
                avgPct: (e)['avgPct'] as int? ?? 0,
              ),
            )
            .toList(),
      ),
      attendance: ParentExperienceAttendance(
        present: attendance['present'] as int? ?? 0,
        absent: attendance['absent'] as int? ?? 0,
        total: attendance['total'] as int? ?? 0,
        pct: attendance['pct'] as int? ?? 0,
      ),
      inventory: ParentExperienceInventory(
        issued: inventory['issued'] as int? ?? 0,
        pending: inventory['pending'] as int? ?? 0,
        items: (inventory['items'] as List<dynamic>? ?? const [])
            .map(
              (i) => ParentInventoryItem(
                id: (i as Map)['id'] as String? ?? '',
                itemName: i['itemName'] as String? ?? '',
                category: i['category'] as String? ?? '',
                status: i['status'] as String? ?? '',
                quantity: i['quantity'] as int? ?? 1,
              ),
            )
            .toList(),
      ),
      communication: ParentExperienceCommunication(
        recentCount: communication['recentCount'] as int? ?? 0,
        lastMessageAt: communication['lastMessageAt'] as String?,
      ),
      guidance: ParentExperienceGuidance(
        available: guidance['available'] as bool? ?? false,
        summary: guidance['summary'] as String?,
        reports: guidanceReports
            .map(
              (r) => ParentGuidanceReport(
                mode: (r as Map)['mode'] as String? ?? 'weekly',
                summary: r['summary'] as String? ?? '',
                createdAt: r['createdAt'] as String? ?? '',
              ),
            )
            .toList(),
      ),
      homeworkIntelligence: ParentHomeworkIntelligence(
        weakTopics: (homeworkIntel['weakTopics'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        suggestedRevision:
            (homeworkIntel['suggestedRevision'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(),
        teacherRecommendations:
            (homeworkIntel['teacherRecommendations'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(),
      ),
    );
  }

  Employee360Profile mapEmployee360(Map<String, dynamic> json) {
    final workload = json['workload'] as Map<String, dynamic>? ?? const {};
    return Employee360Profile(
      profile: Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList(),
      workload: EmployeeWorkload(
        workloadPercent: workload['workloadPercent'] as int? ?? 0,
        burnoutRisk: workload['burnoutRisk'] as String? ?? 'low',
        overloadScore: workload['overloadScore'] as int? ?? 0,
        substitutionLoad: workload['substitutionLoad'] as int? ?? 0,
        coordinatorLoad: workload['coordinatorLoad'] as int? ?? 0,
      ),
      leave: Map<String, dynamic>.from(json['leave'] as Map? ?? const {}),
      insights: (json['insights'] as List<dynamic>? ?? const [])
          .map((i) => i.toString())
          .toList(),
    );
  }

  EmployeeIntelligenceDashboard mapEmployeeIntelligenceDashboard(Map<String, dynamic> json) {
    List<EmployeeInsightRow> mapInsightRows(List<dynamic>? rows, {bool score = false}) {
      return (rows ?? const [])
          .map(
            (r) => EmployeeInsightRow(
              employeeId: (r as Map)['employeeId'] as String? ?? '',
              name: r['name'] as String? ?? '',
              burnoutRisk: r['burnoutRisk'] as String?,
              score: score ? r['score'] as int? : null,
            ),
          )
          .toList();
    }

    return EmployeeIntelligenceDashboard(
      teachersNeedingSupport: mapInsightRows(
        json['teachersNeedingSupport'] as List<dynamic>?,
      ),
      highPerformers: mapInsightRows(json['highPerformers'] as List<dynamic>?, score: true),
      workloadBalancing: (json['workloadBalancing'] as List<dynamic>? ?? const [])
          .map(
            (r) => EmployeeWorkloadRow(
              employeeId: (r as Map)['employeeId'] as String? ?? '',
              name: r['name'] as String? ?? '',
              workloadPercent: r['workloadPercent'] as int? ?? 0,
            ),
          )
          .toList(),
      avgWorkloadPercent: json['avgWorkloadPercent'] as int? ?? 0,
    );
  }

  OperationsHubSnapshot mapOperationsHub(Map<String, dynamic> json) {
    final daily = json['dailySummary'] as Map<String, dynamic>? ?? const {};
    final widgets = json['widgets'] as Map<String, dynamic>? ?? const {};
    return OperationsHubSnapshot(
      schoolHealth: json['schoolHealth'] as int? ?? 0,
      dailySummary: OperationsDailySummary(
        attendancePct: daily['attendancePct'] as int? ?? 0,
        collectionsToday: (daily['collectionsToday'] as num?)?.toDouble() ?? 0,
        communicationsToday: daily['communicationsToday'] as int? ?? 0,
        criticalAlerts: daily['criticalAlerts'] as int? ?? 0,
      ),
      criticalAlerts: (json['criticalAlerts'] as List<dynamic>? ?? const [])
          .map(
            (a) => OperationsAlert(
              id: (a as Map)['id'] as String? ?? '',
              module: a['module'] as String? ?? '',
              title: a['title'] as String? ?? '',
              severity: a['severity'] as String? ?? 'medium',
            ),
          )
          .toList(),
      pendingActions: (json['pendingActions'] as List<dynamic>? ?? const [])
          .map(
            (a) => OperationsAction(
              id: (a as Map)['id'] as String? ?? '',
              module: a['module'] as String? ?? '',
              title: a['title'] as String? ?? '',
            ),
          )
          .toList(),
      widgets: OperationsWidgets(
        todayAttendance: Map<String, int>.from(
          (widgets['todayAttendance'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v as int? ?? 0),
              ) ??
              const {},
        ),
        todayCollections: Map<String, num>.from(
          (widgets['todayCollections'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v as num? ?? 0),
              ) ??
              const {},
        ),
        todayCommunications: Map<String, int>.from(
          (widgets['todayCommunications'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v as int? ?? 0),
              ) ??
              const {},
        ),
        studentRiskAlerts: widgets['studentRiskAlerts'] as int? ?? 0,
        employeeRiskAlerts: widgets['employeeRiskAlerts'] as int? ?? 0,
        inventoryAlerts: widgets['inventoryAlerts'] as int? ?? 0,
        feeAlerts: widgets['feeAlerts'] as int? ?? 0,
      ),
    );
  }

  InvDistributionReports mapDistributionReports(Map<String, dynamic> json) {
    return InvDistributionReports(
      pending: json['pending'] as int? ?? 0,
      issued: json['issued'] as int? ?? 0,
      replacement: json['replacement'] as int? ?? 0,
      lost: json['lost'] as int? ?? 0,
      damaged: json['damaged'] as int? ?? 0,
      byKitCategory: (json['byKitCategory'] as List<dynamic>? ?? const [])
          .map(
            (k) => InvKitCategoryReport(
              category: (k as Map)['category'] as String? ?? '',
              pending: k['pending'] as int? ?? 0,
              issued: k['issued'] as int? ?? 0,
            ),
          )
          .toList(),
    );
  }

  SchoolMemoryEvent mapMemoryEvent(Map<String, dynamic> json) {
    return SchoolMemoryEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      eventDate: json['eventDate'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      description: json['description'] as String?,
      visibility: json['visibility'] as String?,
      albums: (json['albums'] as List<dynamic>? ?? const [])
          .map(
            (a) => SchoolMemoryAlbum(
              id: (a as Map)['id'] as String? ?? '',
              title: a['title'] as String? ?? '',
              mediaCount: a['mediaCount'] as int? ?? 0,
              media: (a['media'] as List<dynamic>? ?? const [])
                  .map(
                    (m) => SchoolMemoryMedia(
                      id: (m as Map)['id'] as String? ?? '',
                      title: m['title'] as String? ?? '',
                      mediaType: m['mediaType'] as String? ?? 'photo',
                      storageUrl: m['storageUrl'] as String? ?? '',
                      thumbnailUrl: m['thumbnailUrl'] as String?,
                      shareToken: m['shareToken'] as String?,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  AchievementPromotion mapPromotion(Map<String, dynamic> json) {
    final analytics = json['analytics'] as Map<String, dynamic>? ?? const {};
    return AchievementPromotion(
      id: json['id'] as String? ?? '',
      achievementType: json['achievementType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      assets: Map<String, dynamic>.from(json['assets'] as Map? ?? const {}),
      analytics: {
        'views': analytics['views'] as int? ?? 0,
        'shares': analytics['shares'] as int? ?? 0,
        'downloads': analytics['downloads'] as int? ?? 0,
      },
      description: json['description'] as String?,
    );
  }

  MemoryUploadPresign mapMemoryUploadPresign(Map<String, dynamic> json) {
    return MemoryUploadPresign(
      albumId: json['albumId'] as String? ?? '',
      signedUrl: json['signedUrl'] as String? ?? '',
      path: json['path'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'photo',
    );
  }

  MemoryUploadConfirm mapMemoryUploadConfirm(Map<String, dynamic> json) {
    return MemoryUploadConfirm(
      mediaId: json['id'] as String? ?? '',
      shareToken: json['shareToken'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }

  MemoryShareLink mapMemoryShareLink(Map<String, dynamic> json) {
    return MemoryShareLink(
      mediaId: json['mediaId'] as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }
}
