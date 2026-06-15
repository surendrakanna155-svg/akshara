import '../../../features/verticals/accommodation/accommodation_models.dart';
import '../repository_query.dart';

abstract class AccommodationRepository {
  Future<AccommodationDashboard> getDashboard({
    required RepositoryQuery query,
  });

  Future<List<Resident>> listResidents({
    required RepositoryQuery query,
  });

  Future<List<RoomOccupancy>> listOccupancy({
    required RepositoryQuery query,
  });

  Future<List<AccommodationAllocation>> listAllocations({
    required RepositoryQuery query,
  });

  Future<AccommodationIntelligence> getIntelligence({
    required RepositoryQuery query,
  });

  Future<AccommodationAllocation> allocateRoom({
    required RepositoryQuery query,
    required String residentId,
    required String roomId,
    required DateTime startDate,
  });

  Future<Resident> registerResident({
    required RepositoryQuery query,
    required String name,
    required String detail,
  });

}