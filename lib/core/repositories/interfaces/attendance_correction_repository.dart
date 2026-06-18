import '../../attendance/attendance_correction_models.dart';
import '../repository_query.dart';

abstract class AttendanceCorrectionRepository {
  Future<List<AttendanceCorrectionRequest>> listCorrections({
    required RepositoryQuery query,
    AttendanceCorrectionStatus? status,
  });

  Future<AttendanceCorrectionRequest?> getCorrection({
    required RepositoryQuery query,
    required String correctionId,
  });

  Future<AttendanceCorrectionRequest> createCorrection({
    required RepositoryQuery query,
    required CreateAttendanceCorrectionRequest request,
  });

  Future<AttendanceCorrectionRequest> updateStatus({
    required RepositoryQuery query,
    required String correctionId,
    required AttendanceCorrectionStatus status,
  });
}
