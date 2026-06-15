import '../../../features/verticals/salon/salon_models.dart';
import '../repository_query.dart';

abstract class SalonRepository {
  Future<SalonDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<List<SalonCustomer>> listCustomers({
    required RepositoryQuery query,
  });

  Future<List<SalonAppointment>> listAppointments({
    required RepositoryQuery query,
  });

  Future<List<SalonService>> listServices({
    required RepositoryQuery query,
  });

  Future<SalonIntelligence> getIntelligence({
    required RepositoryQuery query,
  });

  Future<SalonAppointment> bookSalonAppointment({
    required RepositoryQuery query,
    required String customerId,
    required String serviceId,
    required DateTime scheduledAt,
  });

  Future<SalonCustomer> registerSalonCustomer({
    required RepositoryQuery query,
    required String name,
    required String detail,
  });

}