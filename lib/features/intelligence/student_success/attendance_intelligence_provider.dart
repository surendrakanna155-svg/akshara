import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attendance_intelligence.dart';
import 'student_success_provider.dart';

final attendanceIntelligenceProfilesProvider =
    Provider<AsyncValue<List<AttendanceIntelligenceProfile>>>((ref) {
  final predictions = ref.watch(studentSuccessPredictionsProvider);
  return predictions.whenData(buildAttendanceProfiles);
});

final attendanceIntelligenceSummaryProvider =
    Provider<AsyncValue<AttendanceIntelligenceSummary>>((ref) {
  final profiles = ref.watch(attendanceIntelligenceProfilesProvider);
  return profiles.whenData(summarizeAttendanceProfiles);
});
