import '../../../../../features/school_completion/school_completion_models.dart';

class SchoolCompletionMapper {
  const SchoolCompletionMapper();

  AcademicSubject toSubject(Map<String, dynamic> json) {
    return AcademicSubject(
      id: json['id'] as String,
      subjectCode: json['subjectCode'] as String? ?? json['subject_code'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? json['subject_name'] as String? ?? '',
      category: json['category'] as String? ?? 'core',
      gradeLabels: _stringList(json['gradeLabels'] ?? json['grade_labels']),
      status: json['status'] as String? ?? 'active',
    );
  }

  LessonLogEntry toLessonLog(Map<String, dynamic> json) {
    return LessonLogEntry(
      id: json['id'] as String,
      teacherUserId: json['teacherUserId'] as String? ?? json['teacher_user_id'] as String? ?? '',
      className: json['className'] as String? ?? json['class_name'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? json['section_name'] as String?,
      subjectId: json['subjectId'] as String? ?? json['subject_id'] as String?,
      topic: json['topic'] as String? ?? '',
      outcome: json['outcome'] as String? ?? 'completed',
      notes: json['notes'] as String?,
      recordedOn: json['recordedOn'] as String? ?? json['recorded_on'] as String? ?? '',
    );
  }

  TimetableAutomationResult toAutomationResult(Map<String, dynamic> json) {
    return TimetableAutomationResult(
      timetablesCreated: json['timetablesCreated'] as int? ?? json['timetables_created'] as int? ?? 0,
      subjectsUsed: _stringList(json['subjectsUsed'] ?? json['subjects_used']),
      warnings: _stringList(json['warnings']),
      conflictCount: json['conflictCount'] as int? ?? json['conflict_count'] as int? ?? 0,
    );
  }

  SchoolBranding toBranding(Map<String, dynamic> json) {
    return SchoolBranding(
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      primaryColor: json['primaryColor'] as String? ?? json['primary_color'] as String? ?? '#1B4D89',
      secondaryColor: json['secondaryColor'] as String? ?? json['secondary_color'] as String? ?? '#F5A623',
      logoUrl: json['logoUrl'] as String? ?? json['logo_url'] as String?,
      faviconUrl: json['faviconUrl'] as String? ?? json['favicon_url'] as String?,
      loginBackgroundUrl: json['loginBackgroundUrl'] as String? ?? json['login_background_url'] as String?,
    );
  }

  Map<String, dynamic> brandingToJson(SchoolBranding branding) => {
        'displayName': branding.displayName,
        'tagline': branding.tagline,
        'primaryColor': branding.primaryColor,
        'secondaryColor': branding.secondaryColor,
        if (branding.logoUrl != null) 'logoUrl': branding.logoUrl,
        if (branding.faviconUrl != null) 'faviconUrl': branding.faviconUrl,
        if (branding.loginBackgroundUrl != null) 'loginBackgroundUrl': branding.loginBackgroundUrl,
      };

  WhatsAppProviderConfig toWhatsAppConfig(Map<String, dynamic> json) {
    return WhatsAppProviderConfig(
      id: json['id'] as String?,
      provider: json['provider'] as String? ?? 'stub',
      senderId: json['senderId'] as String? ?? json['sender_id'] as String?,
      apiKeyRef: json['apiKeyRef'] as String? ?? json['api_key_ref'] as String?,
      templateNamespace: json['templateNamespace'] as String? ?? json['template_namespace'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> whatsAppConfigToJson(WhatsAppProviderConfig config) => {
        'provider': config.provider,
        if (config.senderId != null) 'senderId': config.senderId,
        if (config.apiKeyRef != null) 'apiKeyRef': config.apiKeyRef,
        if (config.templateNamespace != null) 'templateNamespace': config.templateNamespace,
        'isActive': config.isActive,
      };

  WhatsAppTestResult toWhatsAppTestResult(Map<String, dynamic> json) {
    return WhatsAppTestResult(
      success: json['success'] as bool? ?? false,
      providerRef: json['providerRef'] as String? ?? json['provider_ref'] as String?,
      error: json['error'] as String?,
    );
  }

  ClassSubjectAssignment toClassSubjectAssignment(Map<String, dynamic> json) {
    return ClassSubjectAssignment(
      id: json['id'] as String,
      academicYearId: json['academicYearId'] as String? ?? json['academic_year_id'] as String? ?? '',
      classId: json['classId'] as String? ?? json['class_id'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? json['section_id'] as String?,
      subjectId: json['subjectId'] as String? ?? json['subject_id'] as String? ?? '',
      isElective: json['isElective'] as bool? ?? json['is_elective'] as bool? ?? false,
      periodsPerWeek: json['periodsPerWeek'] as int? ?? json['periods_per_week'] as int? ?? 5,
      status: json['status'] as String? ?? 'active',
    );
  }

  TeacherSubjectAssignment toTeacherSubjectAssignment(Map<String, dynamic> json) {
    return TeacherSubjectAssignment(
      id: json['id'] as String,
      academicYearId: json['academicYearId'] as String? ?? json['academic_year_id'] as String? ?? '',
      teacherUserId: json['teacherUserId'] as String? ?? json['teacher_user_id'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? json['subject_id'] as String? ?? '',
      classId: json['classId'] as String? ?? json['class_id'] as String?,
      sectionId: json['sectionId'] as String? ?? json['section_id'] as String?,
      periodsPerWeek: json['periodsPerWeek'] as int? ?? json['periods_per_week'] as int? ?? 0,
      isPrimary: json['isPrimary'] as bool? ?? json['is_primary'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );
  }

  SubjectWorkloadEntry toSubjectWorkload(Map<String, dynamic> json) {
    return SubjectWorkloadEntry(
      teacherUserId: json['teacherUserId'] as String? ?? json['teacher_user_id'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? json['subject_id'] as String? ?? '',
      totalPeriods: json['totalPeriods'] as int? ?? json['total_periods'] as int? ?? 0,
      assignmentCount: json['assignmentCount'] as int? ?? json['assignment_count'] as int? ?? 0,
      isOverloaded: json['isOverloaded'] as bool? ?? json['is_overloaded'] as bool? ?? false,
    );
  }

  TeacherLessonAnalytics toTeacherLessonAnalytics(Map<String, dynamic> json) {
    return TeacherLessonAnalytics(
      completedLessons: json['completedLessons'] as int? ?? json['completed_lessons'] as int? ?? 0,
      pendingLessons: json['pendingLessons'] as int? ?? json['pending_lessons'] as int? ?? 0,
      coveragePercent: json['coveragePercent'] as int? ?? json['coverage_percent'] as int? ?? 0,
      pendingTopics: _stringList(json['pendingTopics'] ?? json['pending_topics']),
      upcomingRisk: json['upcomingRisk'] as String? ?? json['upcoming_risk'] as String?,
    );
  }

  PrincipalCoverageEntry toPrincipalCoverage(Map<String, dynamic> json) {
    return PrincipalCoverageEntry(
      className: json['className'] as String? ?? json['class_name'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? json['subject_id'] as String?,
      coveragePercent: json['coveragePercent'] as int? ?? json['coverage_percent'] as int? ?? 0,
      completedTopics: json['completedTopics'] as int? ?? json['completed_topics'] as int? ?? 0,
      totalTopics: json['totalTopics'] as int? ?? json['total_topics'] as int? ?? 0,
      pendingTopics: _stringList(json['pendingTopics'] ?? json['pending_topics']),
    );
  }

  TimetableOptimizationResult toTimetableOptimization(Map<String, dynamic> json) {
    final overload = json['overloadAlerts'] ?? json['overload_alerts'];
    final free = json['freePeriodAnalysis'] ?? json['free_period_analysis'];
    final subs = json['substituteSuggestions'] ?? json['substitute_suggestions'];
    final recs = json['recommendations'];
    return TimetableOptimizationResult(
      qualityScore: json['qualityScore'] as int? ?? json['quality_score'] as int? ?? 0,
      conflictCount: json['conflictCount'] as int? ?? json['conflict_count'] as int? ?? 0,
      overloadAlerts: overload is List
          ? overload.map((e) => TimetableOverloadAlert(
                teacherId: (e as Map)['teacherId'] as String? ?? e['teacher_id'] as String? ?? '',
                teacherName: e['teacherName'] as String? ?? e['teacher_name'] as String? ?? '',
                periodCount: e['periodCount'] as int? ?? e['period_count'] as int? ?? 0,
              )).toList()
          : const [],
      freePeriodAnalysis: free is List
          ? free.map((e) => TimetableFreePeriodEntry(
                teacherId: (e as Map)['teacherId'] as String? ?? e['teacher_id'] as String? ?? '',
                teacherName: e['teacherName'] as String? ?? e['teacher_name'] as String? ?? '',
                freePeriods: e['freePeriods'] as int? ?? e['free_periods'] as int? ?? 0,
              )).toList()
          : const [],
      substituteSuggestions: subs is List
          ? subs.map((e) => TimetableSubstituteSuggestion(
                conflictMessage: (e as Map)['conflictMessage'] as String? ?? e['conflict_message'] as String? ?? '',
                suggestion: e['suggestion'] as String? ?? '',
              )).toList()
          : const [],
      recommendations: recs is List
          ? recs.map((e) => TimetableRecommendation(
                kind: (e as Map)['kind'] as String? ?? '',
                title: e['title'] as String? ?? '',
                detail: e['detail'] as String? ?? '',
                readOnly: e['readOnly'] as bool? ?? e['read_only'] as bool? ?? true,
              )).toList()
          : const [],
    );
  }

  SubstituteCoverageData toSubstituteCoverage(Map<String, dynamic> json) {
    final openSlotsRaw = json['openSlots'] ?? json['open_slots'];
    final candidatesRaw = json['candidates'] ?? json['availableTeachers'] ?? json['available_teachers'];
    return SubstituteCoverageData(
      openSlots: openSlotsRaw is List
          ? openSlotsRaw
              .whereType<Map>()
              .map((slot) => SubstituteOpenSlot(
                    slotId: slot['slotId'] as String? ?? slot['slot_id'] as String? ?? '',
                    academicYearId: slot['academicYearId'] as String? ??
                        slot['academic_year_id'] as String? ??
                        '',
                    className: slot['className'] as String? ?? slot['class_name'] as String? ?? '',
                    sectionName: slot['sectionName'] as String? ?? slot['section_name'] as String? ?? '',
                    subjectName: slot['subjectName'] as String? ?? slot['subject_name'] as String? ?? '',
                    originalTeacherId: slot['originalTeacherId'] as String? ??
                        slot['original_teacher_id'] as String? ??
                        '',
                    originalTeacherName: slot['originalTeacherName'] as String? ??
                        slot['original_teacher_name'] as String? ??
                        '',
                    dayOfWeek: slot['dayOfWeek'] as String? ?? slot['day_of_week'] as String? ?? '',
                    periodLabel: slot['periodLabel'] as String? ?? slot['period_label'] as String? ?? '',
                    slotDate: slot['slotDate'] as String? ?? slot['slot_date'] as String? ?? '',
                  ))
              .toList()
          : const [],
      candidates: candidatesRaw is List
          ? candidatesRaw
              .whereType<Map>()
              .map((candidate) => SubstituteTeacherCandidate(
                    teacherId: candidate['teacherId'] as String? ?? candidate['teacher_id'] as String? ?? '',
                    teacherName:
                        candidate['teacherName'] as String? ?? candidate['teacher_name'] as String? ?? '',
                    subjects: _stringList(candidate['subjects']),
                    freePeriods:
                        candidate['freePeriods'] as int? ?? candidate['free_periods'] as int? ?? 0,
                    dailyLoad: candidate['dailyLoad'] as int? ?? candidate['daily_load'] as int? ?? 0,
                    canNotify:
                        candidate['canNotify'] as bool? ?? candidate['can_notify'] as bool? ?? true,
                  ))
              .toList()
          : const [],
      generatedAt: json['generatedAt'] as String? ?? json['generated_at'] as String? ?? '',
    );
  }

  SubstituteAssignmentResult toSubstituteAssignmentResult(Map<String, dynamic> json) {
    return SubstituteAssignmentResult(
      assignmentId: json['assignmentId'] as String? ?? json['assignment_id'] as String? ?? '',
      slotId: json['slotId'] as String? ?? json['slot_id'] as String? ?? '',
      timetableUpdated:
          json['timetableUpdated'] as bool? ?? json['timetable_updated'] as bool? ?? false,
      notifiedAudience: _stringList(json['notifiedAudience'] ?? json['notified_audience']),
      message: json['message'] as String? ?? 'Substitute assigned successfully.',
    );
  }

  DeliveryAnalytics toDeliveryAnalytics(Map<String, dynamic> json) {
    final byChannelRaw = json['byChannel'] ?? json['by_channel'];
    final byChannel = <String, DeliveryChannelStats>{};
    if (byChannelRaw is Map) {
      for (final entry in byChannelRaw.entries) {
        final v = entry.value as Map;
        byChannel[entry.key.toString()] = DeliveryChannelStats(
          sent: v['sent'] as int? ?? 0,
          failed: v['failed'] as int? ?? 0,
          pending: v['pending'] as int? ?? 0,
        );
      }
    }
    final recent = json['recentEvents'] ?? json['recent_events'];
    return DeliveryAnalytics(
      totalSent: json['totalSent'] as int? ?? json['total_sent'] as int? ?? 0,
      totalFailed: json['totalFailed'] as int? ?? json['total_failed'] as int? ?? 0,
      totalPending: json['totalPending'] as int? ?? json['total_pending'] as int? ?? 0,
      deliveryRate: json['deliveryRate'] as int? ?? json['delivery_rate'] as int? ?? 0,
      byChannel: byChannel,
      recentEvents: recent is List
          ? recent.map((e) {
              final m = e as Map;
              return DeliveryEvent(
                id: m['id'] as String? ?? '',
                channel: m['channel'] as String? ?? '',
                templateCode: m['templateCode'] as String? ?? m['template_code'] as String?,
                recipientLabel: m['recipientLabel'] as String? ?? m['recipient_label'] as String? ?? '',
                status: m['status'] as String? ?? '',
                providerRef: m['providerRef'] as String? ?? m['provider_ref'] as String?,
                errorMessage: m['errorMessage'] as String? ?? m['error_message'] as String?,
                createdAt: m['createdAt'] as String? ?? m['created_at'] as String? ?? '',
              );
            }).toList()
          : const [],
    );
  }

  PilotDashboardSnapshot toPilotDashboard(Map<String, dynamic> json) {
    Map<String, dynamic> map(dynamic v) => v is Map<String, dynamic> ? v : const {};
    final importHealth = map(json['importHealth'] ?? json['import_health']);
    final teacher = map(json['teacherActivation'] ?? json['teacher_activation']);
    final parent = map(json['parentActivation'] ?? json['parent_activation']);
    final otp = map(json['otpDelivery'] ?? json['otp_delivery']);
    PilotActivationStats activation(Map<String, dynamic> m) => PilotActivationStats(
          total: m['total'] as int? ?? 0,
          active: m['active'] as int? ?? 0,
          pending: m['pending'] as int? ?? 0,
          activationRate: m['activationRate'] as int? ?? m['activation_rate'] as int? ?? 0,
        );
    return PilotDashboardSnapshot(
      onboardingStatus: json['onboardingStatus'] as String? ?? json['onboarding_status'] as String? ?? 'not_started',
      setupWizardCompleted: json['setupWizardCompleted'] as bool? ?? json['setup_wizard_completed'] as bool? ?? false,
      pilotScore: json['pilotScore'] as int? ?? json['pilot_score'] as int? ?? 0,
      importHealth: PilotImportHealth(
        totalJobs: importHealth['totalJobs'] as int? ?? importHealth['total_jobs'] as int? ?? 0,
        committedJobs: importHealth['committedJobs'] as int? ?? importHealth['committed_jobs'] as int? ?? 0,
        failedRows: importHealth['failedRows'] as int? ?? importHealth['failed_rows'] as int? ?? 0,
        lastImportAt: importHealth['lastImportAt'] as String? ?? importHealth['last_import_at'] as String?,
      ),
      teacherActivation: activation(teacher),
      parentActivation: activation(parent),
      otpDelivery: PilotOtpDelivery(
        sentLast7Days: otp['sentLast7Days'] as int? ?? otp['sent_last7_days'] as int? ?? 0,
        failedLast7Days: otp['failedLast7Days'] as int? ?? otp['failed_last7_days'] as int? ?? 0,
        deliveryRate: otp['deliveryRate'] as int? ?? otp['delivery_rate'] as int? ?? 0,
      ),
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [for (final item in value) item.toString()];
  }
}
