import '../../../features/verticals/salon/salon_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/salon_repository.dart';
import '../repository_query.dart';

class MockSalonRepository implements SalonRepository {
  MockSalonRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  final List<SalonCustomer> _customers = [
    const SalonCustomer(id: 'sal_cus_1', name: 'Sample SalonCustomer', status: 'active', detail: 'Demo'),
  ];

  final List<SalonAppointment> _appointments = [
    const SalonAppointment(id: 'sal_app_1', name: 'Sample SalonAppointment', status: 'active', detail: 'Demo'),
  ];

  final List<SalonService> _services = [
    const SalonService(id: 'sal_ser_1', name: 'Sample SalonService', status: 'active', detail: 'Demo'),
  ];

  @override
  Future<SalonDashboard> getDashboard({required RepositoryQuery query}) async {
    return SalonDashboard(
      kpis: [
        const SalonKpi(id: 'kpi_1', label: 'Active', value: '12'),
        const SalonKpi(id: 'kpi_2', label: 'Pending', value: '3'),
      ],
      summary: 'Salon operations snapshot',
      generatedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<List<SalonCustomer>> listCustomers({required RepositoryQuery query}) async =>
      List<SalonCustomer>.from(_customers);

  @override
  Future<List<SalonAppointment>> listAppointments({required RepositoryQuery query}) async =>
      List<SalonAppointment>.from(_appointments);

  @override
  Future<List<SalonService>> listServices({required RepositoryQuery query}) async =>
      List<SalonService>.from(_services);

  @override
  Future<SalonIntelligence> getIntelligence({required RepositoryQuery query}) async {
    try {
      final result = await _pipeline.complete(
        AiInferenceRequest(
          prompt: 'Generate salon recommendations',
          taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
          context: const {},
        ),
      );
      return SalonIntelligence(
        recommendations: [
          result.content.isNotEmpty ? result.content : 'Optimize scheduling',
        ],
        insights: const ['Salon demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    } catch (_) {
      return SalonIntelligence(
        recommendations: const ['Optimize scheduling'],
        insights: const ['Salon demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    }
  }

  @override
  Future<SalonAppointment> bookSalonAppointment({
    required RepositoryQuery query,
    required String customerId,
    required String serviceId,
    required DateTime scheduledAt,
  }) async {
    final item = const SalonAppointment(
      id: 'salon_appt_1',
      name: 'New SalonAppointment',
      status: 'scheduled',
    );
    _appointments.add(item);
    return item;
  }

  @override
  Future<SalonCustomer> registerSalonCustomer({
    required RepositoryQuery query,
    required String name,
    required String detail,
  }) async {
    final item = SalonCustomer(
      id: 'salon_cust_1',
      name: name,
      status: 'active',
      detail: detail,
    );
    _customers.add(item);
    return item;
  }
}