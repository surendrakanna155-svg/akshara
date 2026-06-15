import '../../../../features/verticals/restaurant/restaurant_models.dart';
import '../../interfaces/restaurant_repository.dart';
import '../../repository_query.dart';
import 'remote/restaurant_remote_datasource.dart';

class ApiRestaurantRepository implements RestaurantRepository {
  ApiRestaurantRepository({required RestaurantRemoteDataSource remote}) : _remote = remote;

  final RestaurantRemoteDataSource _remote;

  @override
  Future<RestaurantDashboard> getDashboard({required RepositoryQuery query}) async {
    final data = await _remote.fetchDashboard(query: query);
    return RestaurantDashboard(
      kpis: const [],
      summary: (data['summary'] as String?) ?? '',
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<RestaurantTable>> listTables({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<RestaurantOrder>> listOrders({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<KitchenTicket>> listKitchenTickets({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<HospitalityIntelligence> getIntelligence({required RepositoryQuery query}) async {
    final data = await _remote.fetchIntelligence(query: query);
    return HospitalityIntelligence(
      recommendations: [(data['summary'] as String?) ?? ''],
      insights: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<RestaurantOrder> createRestaurantOrder({
    required RepositoryQuery query,
    required String tableId,
    required String items,
    required String notes,
  }) async {
    return const RestaurantOrder(id: '', name: '', status: 'pending');
  }

  @override
  Future<KitchenTicket> updateKitchenTicket({
    required RepositoryQuery query,
    required String ticketId,
    required String status,
  }) async {
    return const KitchenTicket(id: '', name: '', status: 'pending');
  }

}