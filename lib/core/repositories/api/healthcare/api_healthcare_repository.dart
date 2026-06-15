import '../../../../features/verticals/healthcare/healthcare_models.dart';
import '../../interfaces/healthcare_repository.dart';
import '../../repository_query.dart';
import 'remote/healthcare_remote_datasource.dart';

class ApiHealthcareRepository implements HealthcareRepository {
  ApiHealthcareRepository({required HealthcareRemoteDataSource remote}) : _remote = remote;

  final HealthcareRemoteDataSource _remote;

  @override
  Future<HealthcareDashboard> getDashboard({required RepositoryQuery query}) async {
    final data = await _remote.fetchDashboard(query: query);
    return HealthcareDashboard(
      kpis: const [],
      summary: (data['summary'] as String?) ?? '',
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Patient>> listPatients({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<Appointment>> listAppointments({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<Practitioner>> listPractitioners({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<HealthcareIntelligence> getIntelligence({required RepositoryQuery query}) async {
    final data = await _remote.fetchIntelligence(query: query);
    return HealthcareIntelligence(
      recommendations: [
        data['summary'] as String? ?? '',
      ],
      insights: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<Appointment> bookAppointment({
    required RepositoryQuery query,
    required String patientId,
    required String practitionerId,
    required DateTime scheduledAt,
  }) async {
    return const Appointment(id: '', name: '', status: 'pending');
  }

  @override
  Future<Patient> registerPatient({
    required RepositoryQuery query,
    required String name,
    required String detail,
  }) async {
    return const Patient(id: '', name: '', status: 'pending');
  }

}