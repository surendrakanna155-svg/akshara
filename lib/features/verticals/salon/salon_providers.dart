import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'salon_models.dart';

final salonCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewSalonBusiness);
});

final salonDashboardProvider = FutureProvider<SalonDashboard>((ref) async {
  return ref.read(salonRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final salonSalonCustomerListProvider = FutureProvider<List<SalonCustomer>>((ref) async {
  return ref.read(salonRepositoryProvider).listCustomers(
        query: ref.watch(repositoryQueryProvider),
      );
});

final salonSalonAppointmentListProvider = FutureProvider<List<SalonAppointment>>((ref) async {
  return ref.read(salonRepositoryProvider).listAppointments(
        query: ref.watch(repositoryQueryProvider),
      );
});

final salonSalonServiceListProvider = FutureProvider<List<SalonService>>((ref) async {
  return ref.read(salonRepositoryProvider).listServices(
        query: ref.watch(repositoryQueryProvider),
      );
});

final salonIntelligenceProvider = FutureProvider<SalonIntelligence>((ref) async {
  return ref.read(salonRepositoryProvider).getIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});