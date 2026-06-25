import '../../../attendance/attendance_correction_models.dart';
import '../../interfaces/attendance_correction_repository.dart';
import '../../repository_query.dart';
import 'remote/attendance_correction_remote_datasource.dart';

class ApiAttendanceCorrectionRepository implements AttendanceCorrectionRepository {
  ApiAttendanceCorrectionRepository({
    required AttendanceCorrectionRemoteDataSource remote,
  }) : _remote = remote;

  final AttendanceCorrectionRemoteDataSource _remote;

  @override
  Future<List<AttendanceCorrectionRequest>> listCorrections({
    required RepositoryQuery query,
    AttendanceCorrectionStatus? status,
  }) =>
      _remote.fetchCorrections(query: query, status: status);

  @override
  Future<AttendanceCorrectionRequest?> getCorrection({
    required RepositoryQuery query,
    required String correctionId,
  }) =>
      _remote.fetchCorrection(query: query, correctionId: correctionId);

  @override
  Future<AttendanceCorrectionRequest> createCorrection({
    required RepositoryQuery query,
    required CreateAttendanceCorrectionRequest request,
  }) =>
      _remote.createCorrection(query: query, request: request);

  @override
  Future<AttendanceCorrectionRequest> updateStatus({
    required RepositoryQuery query,
    required String correctionId,
    required AttendanceCorrectionStatus status,
  }) =>
      _remote.updateStatus(
        query: query,
        correctionId: correctionId,
        status: status,
      );
}
