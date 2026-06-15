enum ResourceOptimizationDomain {
  staffing,
  timetable,
  room,
  transport,
}

extension ResourceOptimizationDomainX on ResourceOptimizationDomain {
  String get label => switch (this) {
        ResourceOptimizationDomain.staffing => 'Staffing',
        ResourceOptimizationDomain.timetable => 'Timetable',
        ResourceOptimizationDomain.room => 'Room',
        ResourceOptimizationDomain.transport => 'Transport',
      };

  String get promptContext => switch (this) {
        ResourceOptimizationDomain.staffing =>
          'Teacher workloads, substitutions, and support allocation',
        ResourceOptimizationDomain.timetable =>
          'Class schedule conflicts, period balance, and timetable quality',
        ResourceOptimizationDomain.room =>
          'Room utilization, lab assignments, and capacity bottlenecks',
        ResourceOptimizationDomain.transport =>
          'Route capacity, stop delays, and fleet assignment efficiency',
      };
}

class OptimizationRecommendation {
  const OptimizationRecommendation({
    required this.id,
    required this.domain,
    required this.title,
    required this.summary,
    required this.expectedImpact,
    required this.confidence,
    this.applied = false,
    this.dismissed = false,
  });

  final String id;
  final ResourceOptimizationDomain domain;
  final String title;
  final String summary;
  final String expectedImpact;
  final int confidence;
  final bool applied;
  final bool dismissed;

  OptimizationRecommendation copyWith({
    bool? applied,
    bool? dismissed,
  }) {
    return OptimizationRecommendation(
      id: id,
      domain: domain,
      title: title,
      summary: summary,
      expectedImpact: expectedImpact,
      confidence: confidence,
      applied: applied ?? this.applied,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}
