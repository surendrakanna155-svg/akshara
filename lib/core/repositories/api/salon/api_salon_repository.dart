import '../../../../features/verticals/salon/salon_models.dart';
import '../../interfaces/salon_repository.dart';
import '../../repository_query.dart';
import 'remote/salon_remote_datasource.dart';

class ApiSalonRepository implements SalonRepository {
  ApiSalonRepository({required SalonRemoteDataSource remote}) : _remote = remote;

  final SalonRemoteDataSource _remote;

  @override
  Future<SalonDashboard> getDashboard({required RepositoryQuery query}) async {
    final data = await _remote.fetchDashboard(query: query);
    return SalonDashboard(
      kpis: const [],
      summary: (data['summary'] as String?) ?? '',
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<SalonCustomer>> listCustomers({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<SalonAppointment>> listAppointments({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<List<SalonService>> listServices({required RepositoryQuery query}) async =>
      const [];

  @override
  Future<SalonIntelligence> getIntelligence({required RepositoryQuery query}) async {
    final data = await _remote.fetchIntelligence(query: query);
    return SalonIntelligence(
      recommendations: [(data['summary'] as String?) ?? ''],
      insights: const [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<SalonAppointment> bookSalonAppointment({
    required RepositoryQuery query,
    required String customerId,
    required String serviceId,
    required DateTime scheduledAt,
  }) async {
    return const SalonAppointment(id: '', name: '', status: 'pending');
  }

  @override
  Future<SalonCustomer> registerSalonCustomer({
    required RepositoryQuery query,
    required String name,
    required String detail,
  }) async {
    return const SalonCustomer(id: '', name: '', status: 'pending');
  }

}