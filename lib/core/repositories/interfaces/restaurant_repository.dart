import '../../../features/verticals/restaurant/restaurant_models.dart';
import '../repository_query.dart';

abstract class RestaurantRepository {
  Future<RestaurantDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<List<RestaurantTable>> listTables({
    required RepositoryQuery query,
  });

  Future<List<RestaurantOrder>> listOrders({
    required RepositoryQuery query,
  });

  Future<List<KitchenTicket>> listKitchenTickets({
    required RepositoryQuery query,
  });

  Future<HospitalityIntelligence> getIntelligence({
    required RepositoryQuery query,
  });

  Future<RestaurantOrder> createRestaurantOrder({
    required RepositoryQuery query,
    required String tableId,
    required String items,
    required String notes,
  });

  Future<KitchenTicket> updateKitchenTicket({
    required RepositoryQuery query,
    required String ticketId,
    required String status,
  });

}