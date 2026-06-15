import '../../../features/verticals/healthcare/healthcare_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/healthcare_repository.dart';
import '../repository_query.dart';

class MockHealthcareRepository implements HealthcareRepository {
  MockHealthcareRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  final List<Patient> _patients = [
    const Patient(id: 'hea_pat_1', name: 'Sample Patient', status: 'active', detail: 'Demo'),
  ];

  final List<Appointment> _appointments = [
    const Appointment(id: 'hea_app_1', name: 'Sample Appointment', status: 'active', detail: 'Demo'),
  ];

  final List<Practitioner> _practitioners = [
    const Practitioner(id: 'hea_pra_1', name: 'Sample Practitioner', status: 'active', detail: 'Demo'),
  ];

  @override
  Future<HealthcareDashboard> getDashboard({required RepositoryQuery query}) async {
    return HealthcareDashboard(
      kpis: [
        const HealthcareKpi(id: 'kpi_1', label: 'Active', value: '12'),
        const HealthcareKpi(id: 'kpi_2', label: 'Pending', value: '3'),
      ],
      summary: 'Healthcare operations snapshot',
      generatedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<List<Patient>> listPatients({required RepositoryQuery query}) async =>
      List<Patient>.from(_patients);

  @override
  Future<List<Appointment>> listAppointments({required RepositoryQuery query}) async =>
      List<Appointment>.from(_appointments);

  @override
  Future<List<Practitioner>> listPractitioners({required RepositoryQuery query}) async =>
      List<Practitioner>.from(_practitioners);

  @override
  Future<HealthcareIntelligence> getIntelligence({required RepositoryQuery query}) async {
    try {
      final result = await _pipeline.complete(
        AiInferenceRequest(
          prompt: 'Generate healthcare recommendations',
          taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
          context: const {},
        ),
      );
      return HealthcareIntelligence(
        recommendations: [
          result.content.isNotEmpty ? result.content : 'Optimize scheduling',
        ],
        insights: const ['Healthcare demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    } catch (_) {
      return HealthcareIntelligence(
        recommendations: const ['Optimize scheduling'],
        insights: const ['Healthcare demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    }
  }

  @override
  Future<Appointment> bookAppointment({
    required RepositoryQuery query,
    required String patientId,
    required String practitionerId,
    required DateTime scheduledAt,
  }) async {
    final item = const Appointment(
      id: 'hc_appt_1',
      name: 'New Appointment',
      status: 'scheduled',
    );
    _appointments.add(item);
    return item;
  }

  @override
  Future<Patient> registerPatient({
    required RepositoryQuery query,
    required String name,
    required String detail,
  }) async {
    final item = Patient(
      id: 'hc_patient_1',
      name: name,
      status: 'active',
      detail: detail,
    );
    _patients.add(item);
    return item;
  }
}