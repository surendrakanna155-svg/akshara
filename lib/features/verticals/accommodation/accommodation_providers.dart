import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'accommodation_models.dart';

final accommodationCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewAccommodation);
});

final accommodationDashboardProvider = FutureProvider<AccommodationDashboard>((ref) async {
  return ref.read(accommodationRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final accommodationResidentListProvider = FutureProvider<List<Resident>>((ref) async {
  return ref.read(accommodationRepositoryProvider).listResidents(
        query: ref.watch(repositoryQueryProvider),
      );
});

final accommodationRoomOccupancyListProvider = FutureProvider<List<RoomOccupancy>>((ref) async {
  return ref.read(accommodationRepositoryProvider).listOccupancy(
        query: ref.watch(repositoryQueryProvider),
      );
});

final accommodationAccommodationAllocationListProvider = FutureProvider<List<AccommodationAllocation>>((ref) async {
  return ref.read(accommodationRepositoryProvider).listAllocations(
        query: ref.watch(repositoryQueryProvider),
      );
});

final accommodationIntelligenceProvider = FutureProvider<AccommodationIntelligence>((ref) async {
  return ref.read(accommodationRepositoryProvider).getIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});