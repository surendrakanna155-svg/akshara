enum SchoolLifecycleStatus {
  trial('trial'),
  active('active'),
  suspended('suspended'),
  churnRisk('churn_risk');

  const SchoolLifecycleStatus(this.value);
  final String value;

  static SchoolLifecycleStatus fromValue(String raw) {
    for (final status in SchoolLifecycleStatus.values) {
      if (status.value == raw) return status;
    }
    return SchoolLifecycleStatus.trial;
  }
}

class PortfolioKpi {
  const PortfolioKpi({
    required this.id,
    required this.label,
    required this.value,
    this.deltaLabel,
    this.trend,
  });

  final String id;
  final String label;
  final String value;
  final String? deltaLabel;
  final String? trend;
}

class SchoolHealthScore {
  const SchoolHealthScore({
    required this.schoolId,
    required this.score,
    required this.band,
    required this.factors,
    this.lastEvaluatedAt,
  });

  final String schoolId;
  final int score;
  final String band;
  final List<String> factors;
  final DateTime? lastEvaluatedAt;
}

class SchoolLifecycleRecord {
  const SchoolLifecycleRecord({
    required this.schoolId,
    required this.schoolName,
    required this.status,
    required this.planName,
    required this.region,
    required this.healthScore,
    required this.studentsCount,
    required this.staffCount,
    required this.updatedAt,
  });

  final String schoolId;
  final String schoolName;
  final SchoolLifecycleStatus status;
  final String planName;
  final String region;
  final SchoolHealthScore healthScore;
  final int studentsCount;
  final int staffCount;
  final DateTime updatedAt;
}

class PortfolioAlert {
  const PortfolioAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.schoolId,
    required this.schoolName,
    required this.createdAt,
    this.dismissed = false,
  });

  final String id;
  final String title;
  final String message;
  final String severity;
  final String schoolId;
  final String schoolName;
  final DateTime createdAt;
  final bool dismissed;
}

class PortfolioAction {
  const PortfolioAction({
    required this.id,
    required this.title,
    required this.description,
    required this.schoolId,
    required this.schoolName,
    required this.dueAt,
    this.completed = false,
  });

  final String id;
  final String title;
  final String description;
  final String schoolId;
  final String schoolName;
  final DateTime dueAt;
  final bool completed;
}

class SchoolOnboardingDraft {
  const SchoolOnboardingDraft({
    required this.id,
    required this.schoolName,
    required this.contactName,
    required this.contactEmail,
    required this.planName,
    required this.country,
    required this.studentCapacity,
    required this.activateNow,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolName;
  final String contactName;
  final String contactEmail;
  final String planName;
  final String country;
  final int studentCapacity;
  final bool activateNow;
  final DateTime createdAt;
  final DateTime updatedAt;

  SchoolOnboardingDraft copyWith({
    String? schoolName,
    String? contactName,
    String? contactEmail,
    String? planName,
    String? country,
    int? studentCapacity,
    bool? activateNow,
    DateTime? updatedAt,
  }) {
    return SchoolOnboardingDraft(
      id: id,
      schoolName: schoolName ?? this.schoolName,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      planName: planName ?? this.planName,
      country: country ?? this.country,
      studentCapacity: studentCapacity ?? this.studentCapacity,
      activateNow: activateNow ?? this.activateNow,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SchoolPortfolioDashboard {
  const SchoolPortfolioDashboard({
    required this.kpis,
    required this.alerts,
    required this.schools,
    required this.pendingActions,
  });

  final List<PortfolioKpi> kpis;
  final List<PortfolioAlert> alerts;
  final List<SchoolLifecycleRecord> schools;
  final List<PortfolioAction> pendingActions;
}
