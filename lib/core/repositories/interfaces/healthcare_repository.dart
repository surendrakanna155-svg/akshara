import '../../../features/verticals/healthcare/healthcare_models.dart';
import '../repository_query.dart';

abstract class HealthcareRepository {
  Future<HealthcareDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<List<Patient>> listPatients({
    required RepositoryQuery query,
  });

  Future<List<Appointment>> listAppointments({
    required RepositoryQuery query,
  });

  Future<List<Practitioner>> listPractitioners({
    required RepositoryQuery query,
  });

  Future<HealthcareIntelligence> getIntelligence({
    required RepositoryQuery query,
  });

  Future<Appointment> bookAppointment({
    required RepositoryQuery query,
    required String patientId,
    required String practitionerId,
    required DateTime scheduledAt,
  });

  Future<Patient> registerPatient({
    required RepositoryQuery query,
    required String name,
    required String detail,
  });

}