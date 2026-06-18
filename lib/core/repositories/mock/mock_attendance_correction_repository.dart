import '../../attendance/attendance_correction_models.dart';
import '../../attendance/attendance_correction_store.dart';
import '../interfaces/attendance_correction_repository.dart';
import '../repository_query.dart';

class MockAttendanceCorrectionRepository
    implements AttendanceCorrectionRepository {
  MockAttendanceCorrectionRepository({AttendanceCorrectionStore? store})
      : _store = store ?? AttendanceCorrectionStore.instance;

  final AttendanceCorrectionStore _store;

  @override
  Future<List<AttendanceCorrectionRequest>> listCorrections({
    required RepositoryQuery query,
    AttendanceCorrectionStatus? status,
  }) async {
    final all = _store.listAll();
    if (status == null) return all;
    return all.where((item) => item.status == status).toList(growable: false);
  }

  @override
  Future<AttendanceCorrectionRequest?> getCorrection({
    required RepositoryQuery query,
    required String correctionId,
  }) async {
    return _store.byId(correctionId);
  }

  @override
  Future<AttendanceCorrectionRequest> createCorrection({
    required RepositoryQuery query,
    required CreateAttendanceCorrectionRequest request,
  }) async {
    return _store.create(request);
  }

  @override
  Future<AttendanceCorrectionRequest> updateStatus({
    required RepositoryQuery query,
    required String correctionId,
    required AttendanceCorrectionStatus status,
  }) async {
    return _store.updateStatus(id: correctionId, status: status);
  }
}
