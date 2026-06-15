import '../../../../features/verticals/accommodation/accommodation_models.dart';
import '../../interfaces/accommodation_repository.dart';
import '../../repository_query.dart';
import 'remote/accommodation_remote_datasource.dart';

class ApiAccommodationRepository implements AccommodationRepository {
  ApiAccommodationRepository({required AccommodationRemoteDataSource remote}) : _remote = remote;

  final AccommodationRemoteDataSource _remote;

  @override
  Future<AccommodationDashboard> getDashboard({required RepositoryQuery query}) async {
    final data = await _remote.fetchDashboard(query: query);
    return AccommodationDashboard(
      kpis: const [],
      summary: (data['summary'] as String?) ?? '',
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Resident>> listResidents({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<RoomOccupancy>> listOccupancy({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<AccommodationAllocation>> listAllocations({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<AccommodationIntelligence> getIntelligence({required RepositoryQuery query}) async {
    final data = await _remote.fetchIntelligence(query: query);
    return AccommodationIntelligence(
      recommendations: [(data['summary'] as String?) ?? ''],
      insights: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<AccommodationAllocation> allocateRoom({
    required RepositoryQuery query,
    required String residentId,
    required String roomId,
    required DateTime startDate,
  }) async {
    return const AccommodationAllocation(id: '', name: '', status: 'pending');
  }

  @override
  Future<Resident> registerResident({
    required RepositoryQuery query,
    required String name,
    required String detail,
  }) async {
    return const Resident(id: '', name: '', status: 'pending');
  }

}