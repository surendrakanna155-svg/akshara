import '../../../features/verticals/accommodation/accommodation_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/accommodation_repository.dart';
import '../repository_query.dart';

class MockAccommodationRepository implements AccommodationRepository {
  MockAccommodationRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  final List<Resident> _residents = [
    const Resident(id: 'acc_res_1', name: 'Sample Resident', status: 'active', detail: 'Demo'),
  ];

  final List<RoomOccupancy> _occupancy = [
    const RoomOccupancy(id: 'acc_occ_1', name: 'Sample RoomOccupancy', status: 'active', detail: 'Demo'),
  ];

  final List<AccommodationAllocation> _allocations = [
    const AccommodationAllocation(id: 'acc_all_1', name: 'Sample AccommodationAllocation', status: 'active', detail: 'Demo'),
  ];

  @override
  Future<AccommodationDashboard> getDashboard({required RepositoryQuery query}) async {
    return AccommodationDashboard(
      kpis: [
        const AccommodationKpi(id: 'kpi_1', label: 'Active', value: '12'),
        const AccommodationKpi(id: 'kpi_2', label: 'Pending', value: '3'),
      ],
      summary: 'Accommodation operations snapshot',
      generatedAt: DateTime(2026, 6, 15),
    );
  }

  @override
  Future<List<Resident>> listResidents({required RepositoryQuery query}) async =>
      List<Resident>.from(_residents);

  @override
  Future<List<RoomOccupancy>> listOccupancy({required RepositoryQuery query}) async =>
      List<RoomOccupancy>.from(_occupancy);

  @override
  Future<List<AccommodationAllocation>> listAllocations({required RepositoryQuery query}) async =>
      List<AccommodationAllocation>.from(_allocations);

  @override
  Future<AccommodationIntelligence> getIntelligence({required RepositoryQuery query}) async {
    try {
      final result = await _pipeline.complete(
        AiInferenceRequest(
          prompt: 'Generate accommodation recommendations',
          taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
          context: const {},
        ),
      );
      return AccommodationIntelligence(
        recommendations: [
          result.content.isNotEmpty ? result.content : 'Optimize occupancy',
        ],
        insights: const ['Accommodation demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    } catch (_) {
      return AccommodationIntelligence(
        recommendations: const ['Optimize occupancy'],
        insights: const ['Accommodation demand trending up'],
        generatedAt: DateTime(2026, 6, 15),
      );
    }
  }

  @override
  Future<AccommodationAllocation> allocateRoom({
    required RepositoryQuery query,
    required String residentId,
    required String roomId,
    required DateTime startDate,
  }) async {
    final item = AccommodationAllocation(
      id: 'acc_room_1',
      name: 'Room $roomId for $residentId',
      status: 'allocated',
    );
    _allocations.add(item);
    return item;
  }

  @override
  Future<Resident> registerResident({
    required RepositoryQuery query,
    required String name,
    required String detail,
  }) async {
    final item = Resident(
      id: 'acc_res_1',
      name: name,
      status: 'active',
      detail: detail,
    );
    _residents.add(item);
    return item;
  }
}