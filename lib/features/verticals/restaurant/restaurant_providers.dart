import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'restaurant_models.dart';

final restaurantCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewRestaurantHospitality);
});

final restaurantDashboardProvider = FutureProvider<RestaurantDashboard>((ref) async {
  return ref.read(restaurantRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final restaurantRestaurantTableListProvider = FutureProvider<List<RestaurantTable>>((ref) async {
  return ref.read(restaurantRepositoryProvider).listTables(
        query: ref.watch(repositoryQueryProvider),
      );
});

final restaurantRestaurantOrderListProvider = FutureProvider<List<RestaurantOrder>>((ref) async {
  return ref.read(restaurantRepositoryProvider).listOrders(
        query: ref.watch(repositoryQueryProvider),
      );
});

final restaurantKitchenTicketListProvider = FutureProvider<List<KitchenTicket>>((ref) async {
  return ref.read(restaurantRepositoryProvider).listKitchenTickets(
        query: ref.watch(repositoryQueryProvider),
      );
});

final restaurantIntelligenceProvider = FutureProvider<HospitalityIntelligence>((ref) async {
  return ref.read(restaurantRepositoryProvider).getIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});