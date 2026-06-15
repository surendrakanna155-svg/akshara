import '../../../features/verticals/restaurant/restaurant_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/restaurant_repository.dart';
import '../repository_query.dart';

class MockRestaurantRepository implements RestaurantRepository {
  MockRestaurantRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  final List<RestaurantTable> _tables = [
    const RestaurantTable(id: 'res_tab_1', name: 'Sample RestaurantTable', status: 'active', detail: 'Demo'),
  ];

  final List<RestaurantOrder> _orders = [
    const RestaurantOrder(id: 'res_ord_1', name: 'Sample RestaurantOrder', status: 'active', detail: 'Demo'),
  ];

  final List<KitchenTicket> _kitchen = [
    const KitchenTicket(id: 'res_kit_1', name: 'Sample KitchenTicket', status: 'active', detail: 'Demo'),
  ];

  @override
  Future<RestaurantDashboard> getDashboard({required RepositoryQuery query}) async {
    return RestaurantDashboard(
      kpis: [
        const RestaurantKpi(id: 'kpi_1', label: 'Active', value: '12'),
        const RestaurantKpi(id: 'kpi_2', label: 'Pending', value: '3'),
      ],
      summary: 'Restaurant operations snapshot',
      generatedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<List<RestaurantTable>> listTables({required RepositoryQuery query}) async =>
      List<RestaurantTable>.from(_tables);

  @override
  Future<List<RestaurantOrder>> listOrders({required RepositoryQuery query}) async =>
      List<RestaurantOrder>.from(_orders);

  @override
  Future<List<KitchenTicket>> listKitchenTickets({required RepositoryQuery query}) async =>
      List<KitchenTicket>.from(_kitchen);

  @override
  Future<HospitalityIntelligence> getIntelligence({required RepositoryQuery query}) async {
    try {
      final result = await _pipeline.complete(
        AiInferenceRequest(
          prompt: 'Generate restaurant recommendations',
          taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
          context: const {},
        ),
      );
      return HospitalityIntelligence(
        recommendations: [
          result.content.isNotEmpty ? result.content : 'Optimize kitchen flow',
        ],
        insights: const ['Restaurant demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    } catch (_) {
      return HospitalityIntelligence(
        recommendations: const ['Optimize kitchen flow'],
        insights: const ['Restaurant demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    }
  }

  @override
  Future<RestaurantOrder> createRestaurantOrder({
    required RepositoryQuery query,
    required String tableId,
    required String items,
    required String notes,
  }) async {
    final item = const RestaurantOrder(
      id: 'rest_order_1',
      name: 'New RestaurantOrder',
      status: 'scheduled',
    );
    _orders.add(item);
    return item;
  }

  @override
  Future<KitchenTicket> updateKitchenTicket({
    required RepositoryQuery query,
    required String ticketId,
    required String status,
  }) async {
    final index = _kitchen.indexWhere((t) => t.id == ticketId);
    final item = KitchenTicket(
      id: ticketId,
      name: 'Kitchen ticket',
      status: status,
    );
    if (index >= 0) {
      _kitchen[index] = item;
    } else {
      _kitchen.add(item);
    }
    return item;
  }
}