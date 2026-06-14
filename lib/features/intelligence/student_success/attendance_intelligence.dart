import 'student_success_models.dart';

/// Attendance risk tiers from predicted attendance (INTEL-07).
enum AttendanceRiskTier {
  stable('Stable', 0),
  watch('Watch', 1),
  atRisk('At risk', 2),
  chronic('Chronic absence risk', 3);

  const AttendanceRiskTier(this.label, this.sortOrder);

  final String label;
  final int sortOrder;
}

class AttendanceIntelligenceProfile {
  const AttendanceIntelligenceProfile({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.tier,
    required this.attendancePrediction,
    required this.primarySignal,
    required this.recommendedAction,
  });

  final String studentId;
  final String studentName;
  final String className;
  final AttendanceRiskTier tier;
  final int attendancePrediction;
  final String primarySignal;
  final String recommendedAction;
}

class AttendanceIntelligenceSummary {
  const AttendanceIntelligenceSummary({
    required this.totalFlagged,
    required this.chronicCount,
    required this.atRiskCount,
    required this.watchCount,
    required this.averagePrediction,
    required this.topProfiles,
  });

  final int totalFlagged;
  final int chronicCount;
  final int atRiskCount;
  final int watchCount;
  final int averagePrediction;
  final List<AttendanceIntelligenceProfile> topProfiles;
}

AttendanceRiskTier classifyAttendanceTier(int attendancePrediction) {
  if (attendancePrediction < 60) return AttendanceRiskTier.chronic;
  if (attendancePrediction < 75) return AttendanceRiskTier.atRisk;
  if (attendancePrediction < 85) return AttendanceRiskTier.watch;
  return AttendanceRiskTier.stable;
}

String _attendanceActionForTier(AttendanceRiskTier tier) => switch (tier) {
      AttendanceRiskTier.chronic =>
        'Escalate to admin and schedule parent conference within 72 hours.',
      AttendanceRiskTier.atRisk =>
        'Daily attendance check-in with class teacher for 2 weeks.',
      AttendanceRiskTier.watch => 'Weekly attendance review and SMS reminder to parent.',
      AttendanceRiskTier.stable => 'Continue standard monitoring.',
    };

AttendanceIntelligenceProfile attendanceProfileFromSnapshot(StudentSuccessSnapshot snapshot) {
  final tier = classifyAttendanceTier(snapshot.attendancePrediction);
  final signal = snapshot.riskSignals
      .where((r) => (r['label']?.toString().toLowerCase() ?? '').contains('attend'))
      .map((r) => r['label']?.toString())
      .whereType<String>()
      .firstOrNull;

  return AttendanceIntelligenceProfile(
    studentId: snapshot.studentId,
    studentName: snapshot.studentName,
    className: snapshot.className,
    tier: tier,
    attendancePrediction: snapshot.attendancePrediction,
    primarySignal: signal ?? 'Predicted attendance ${snapshot.attendancePrediction}%',
    recommendedAction: _attendanceActionForTier(tier),
  );
}

List<AttendanceIntelligenceProfile> buildAttendanceProfiles(
  List<StudentSuccessSnapshot> snapshots, {
  AttendanceRiskTier minimumTier = AttendanceRiskTier.watch,
}) {
  final profiles = snapshots.map(attendanceProfileFromSnapshot).toList()
    ..sort((a, b) {
      final tierCompare = b.tier.sortOrder.compareTo(a.tier.sortOrder);
      if (tierCompare != 0) return tierCompare;
      return a.attendancePrediction.compareTo(b.attendancePrediction);
    });

  return profiles
      .where((p) => p.tier.sortOrder >= minimumTier.sortOrder)
      .toList(growable: false);
}

AttendanceIntelligenceSummary summarizeAttendanceProfiles(List<AttendanceIntelligenceProfile> profiles) {
  final avg = profiles.isEmpty
      ? 0
      : (profiles.map((p) => p.attendancePrediction).reduce((a, b) => a + b) / profiles.length)
          .round();

  return AttendanceIntelligenceSummary(
    totalFlagged: profiles.length,
    chronicCount: profiles.where((p) => p.tier == AttendanceRiskTier.chronic).length,
    atRiskCount: profiles.where((p) => p.tier == AttendanceRiskTier.atRisk).length,
    watchCount: profiles.where((p) => p.tier == AttendanceRiskTier.watch).length,
    averagePrediction: avg,
    topProfiles: profiles.take(12).toList(growable: false),
  );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
