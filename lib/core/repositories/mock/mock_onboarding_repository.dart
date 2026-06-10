import '../../../features/onboarding/onboarding_models.dart';
import '../interfaces/onboarding_repository.dart';
import '../repository_query.dart';

class MockOnboardingRepository implements OnboardingRepository {
  final List<OnboardingImportJob> _jobs = [];
  final List<OnboardingInvite> _invites = [];

  @override
  Future<OnboardingDashboardData> getDashboard({required RepositoryQuery query}) async {
    return OnboardingDashboardData(
      recentJobs: List<OnboardingImportJob>.from(_jobs),
      pendingInvites: _invites.where((i) => i.status == 'pending' || i.status == 'sent').length,
      totalInvites: _invites.length,
    );
  }

  @override
  Future<OnboardingImportPreviewResult> previewStudentImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  }) async {
    return _preview('student', fileName, rows);
  }

  @override
  Future<OnboardingImportPreviewResult> previewTeacherImport({
    required RepositoryQuery query,
    required String fileName,
    required List<Map<String, dynamic>> rows,
  }) async {
    return _preview('teacher', fileName, rows);
  }

  OnboardingImportPreviewResult _preview(
    String type,
    String fileName,
    List<Map<String, dynamic>> rows,
  ) {
    final preview = <OnboardingImportPreviewRow>[];
    var valid = 0;
    var invalid = 0;
    var duplicate = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final errors = <String>[];
      if (type == 'student') {
        if ((row['studentName'] ?? row['student_name'] ?? '').toString().isEmpty) {
          errors.add('studentName is required');
        }
        if ((row['admissionNumber'] ?? row['admission_number'] ?? '').toString().isEmpty) {
          errors.add('admissionNumber is required');
        }
      } else {
        if ((row['displayName'] ?? row['name'] ?? '').toString().isEmpty) {
          errors.add('displayName is required');
        }
        if ((row['phone'] ?? '').toString().isEmpty) errors.add('phone is required');
      }
      final status = errors.isEmpty ? 'valid' : 'invalid';
      if (status == 'valid') valid++;
      if (status == 'invalid') invalid++;
      preview.add(OnboardingImportPreviewRow(rowNumber: i + 1, status: status, errors: errors));
    }
    final job = OnboardingImportJob(
      id: 'job_${_jobs.length + 1}',
      importType: type,
      status: 'previewed',
      fileName: fileName,
      totalRows: rows.length,
      validRows: valid,
      invalidRows: invalid,
      duplicateRows: duplicate,
      committedRows: 0,
    );
    _jobs.insert(0, job);
    return OnboardingImportPreviewResult(job: job, preview: preview);
  }

  @override
  Future<OnboardingImportJob> commitImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) throw StateError('job not found');
    final job = _jobs[index];
    _jobs[index] = OnboardingImportJob(
      id: job.id,
      importType: job.importType,
      status: 'committed',
      fileName: job.fileName,
      totalRows: job.totalRows,
      validRows: job.validRows,
      invalidRows: job.invalidRows,
      duplicateRows: job.duplicateRows,
      committedRows: job.validRows,
    );
    return _jobs[index];
  }

  @override
  Future<OnboardingImportJob> rollbackImport({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) throw StateError('job not found');
    final job = _jobs[index];
    _jobs[index] = OnboardingImportJob(
      id: job.id,
      importType: job.importType,
      status: 'rolled_back',
      fileName: job.fileName,
      totalRows: job.totalRows,
      validRows: job.validRows,
      invalidRows: job.invalidRows,
      duplicateRows: job.duplicateRows,
      committedRows: 0,
    );
    return _jobs[index];
  }

  @override
  Future<List<OnboardingImportJob>> listImportJobs({required RepositoryQuery query}) async {
    return List<OnboardingImportJob>.from(_jobs);
  }

  @override
  Future<OnboardingInvite> createInvite({
    required RepositoryQuery query,
    required String inviteType,
    required String recipientPhone,
    required String recipientLabel,
    String? studentId,
    String channel = 'whatsapp',
  }) async {
    final invite = OnboardingInvite(
      id: 'inv_${_invites.length + 1}',
      inviteType: inviteType,
      recipientPhone: recipientPhone,
      recipientLabel: recipientLabel,
      status: 'sent',
      channel: channel,
      deepLink: 'https://app.akshara.test/invite/mock',
      whatsappLink: 'https://wa.me/?text=Welcome',
    );
    _invites.insert(0, invite);
    return invite;
  }

  @override
  Future<List<OnboardingInvite>> listInvites({required RepositoryQuery query}) async {
    return List<OnboardingInvite>.from(_invites);
  }
}
