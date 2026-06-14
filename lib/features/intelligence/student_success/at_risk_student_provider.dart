import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'at_risk_student_intelligence.dart';
import 'student_success_provider.dart';

final atRiskStudentProfilesProvider = Provider<AsyncValue<List<AtRiskStudentProfile>>>((ref) {
  final predictions = ref.watch(studentSuccessPredictionsProvider);
  return predictions.whenData(
    (rows) => buildAtRiskProfiles(rows),
  );
});

final atRiskIntelligenceSummaryProvider = Provider<AsyncValue<AtRiskIntelligenceSummary>>((ref) {
  final profiles = ref.watch(atRiskStudentProfilesProvider);
  return profiles.whenData(summarizeAtRiskProfiles);
});
