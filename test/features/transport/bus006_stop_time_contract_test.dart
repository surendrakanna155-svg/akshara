import 'package:akshara_erp/core/repositories/api/transport/dto/transport_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/transport/mapper/transport_mapper.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// BUS-006 / BUS-007 — stop-time contract and drop-time preservation.
///
/// The defects these pin:
///
/// BUS-006 — the backend write path (`handleAddStop` / `handleUpdateStop`) has
/// always persisted `pickupTime` + `dropTime`, but the client mapper read
/// `scheduledTime`, a key nothing ever wrote. Every stop created through the
/// product therefore rendered with a blank pickup time however carefully the
/// admin typed it. The contract fixture emitted `scheduledTime` too, so the
/// contract test agreed with the bug and could never have caught it.
///
/// BUS-007 — the edit dialog built its drop-time controller EMPTY regardless of
/// the persisted value and submitted it unconditionally, so editing only a
/// stop's NAME silently wiped its drop time.
void main() {
  const query = RepositoryQuery.demo;

  group('BUS-006 · canonical stop-time mapping', () {
    test('maps the canonical pickupTime/dropTime keys the backend writes', () {
      final route = TransportMapper().toRoutes(
        TransportRoutesResponseDto(
          items: [
            TransportRouteDto(
              raw: {
                'id': 'route-1',
                'name': 'Route 1',
                'stops': [
                  {
                    'id': 'stop-1',
                    'name': 'Green Park Gate',
                    'sequence': 1,
                    'pickupTime': '7:05 AM',
                    'dropTime': '3:40 PM',
                  },
                ],
              },
            ),
          ],
        ),
      ).single;

      final stop = route.stops.single;
      expect(stop.pickupTime, '7:05 AM');
      expect(stop.dropTime, '3:40 PM');
    });

    test('still reads legacy scheduledTime rows (read-only back-compat)', () {
      final route = TransportMapper().toRoutes(
        TransportRoutesResponseDto(
          items: [
            TransportRouteDto(
              raw: {
                'id': 'route-1',
                'name': 'Route 1',
                'stops': [
                  {
                    'id': 'stop-legacy',
                    'name': 'Lake View Colony',
                    'sequence': 1,
                    'scheduledTime': '7:05 AM',
                  },
                ],
              },
            ),
          ],
        ),
      ).single;

      final stop = route.stops.single;
      expect(stop.pickupTime, '7:05 AM',
          reason: 'legacy seed rows must remain readable');
      expect(stop.dropTime, '');
    });

    test('canonical key wins when a row carries both', () {
      final route = TransportMapper().toRoutes(
        TransportRoutesResponseDto(
          items: [
            TransportRouteDto(
              raw: {
                'id': 'route-1',
                'name': 'Route 1',
                'stops': [
                  {
                    'id': 'stop-1',
                    'name': 'Mixed',
                    'sequence': 1,
                    'pickupTime': '7:05 AM',
                    'scheduledTime': '9:99 XX',
                  },
                ],
              },
            ),
          ],
        ),
      ).single;

      expect(route.stops.single.pickupTime, '7:05 AM');
    });
  });

  group('BUS-007 · drop time survives an unrelated edit', () {
    test('editing ONLY the name preserves both persisted times', () async {
      final repo = MockTransportRepository();
      final routes = await repo.getRoutes(query: query);
      final routeId = routes.items.first.id;

      final added = await repo.addStop(
        query: query,
        request: AddTransportStopRequest(
          routeId: routeId,
          name: 'Green Park Gate',
          pickupTime: '7:05 AM',
          dropTime: '3:40 PM',
        ),
      );
      final created = added.stops.last;
      expect(created.pickupTime, '7:05 AM');
      expect(created.dropTime, '3:40 PM',
          reason: 'add must persist the drop time it was given');

      // The exact regression: rename only. Times are omitted from the request.
      final renamed = await repo.updateStop(
        query: query,
        request: UpdateTransportStopRequest(
          routeId: routeId,
          stopId: created.id,
          name: 'Green Park Main Gate',
        ),
      );

      final after = renamed.stops.firstWhere((s) => s.id == created.id);
      expect(after.name, 'Green Park Main Gate');
      expect(after.pickupTime, '7:05 AM');
      expect(after.dropTime, '3:40 PM',
          reason: 'renaming a stop must never erase its drop time');
    });

    test('an explicit time change still applies', () async {
      final repo = MockTransportRepository();
      final routes = await repo.getRoutes(query: query);
      final routeId = routes.items.first.id;

      final added = await repo.addStop(
        query: query,
        request: AddTransportStopRequest(
          routeId: routeId,
          name: 'Stop A',
          pickupTime: '7:00 AM',
          dropTime: '3:00 PM',
        ),
      );
      final created = added.stops.last;

      final updated = await repo.updateStop(
        query: query,
        request: UpdateTransportStopRequest(
          routeId: routeId,
          stopId: created.id,
          dropTime: '3:45 PM',
        ),
      );

      final after = updated.stops.firstWhere((s) => s.id == created.id);
      expect(after.pickupTime, '7:00 AM', reason: 'untouched field preserved');
      expect(after.dropTime, '3:45 PM', reason: 'explicit change applied');
    });

    test('reordering stops carries both times through resequencing', () async {
      final repo = MockTransportRepository();
      final routes = await repo.getRoutes(query: query);
      final route = routes.items.first;
      final ids = [for (final s in route.stops) s.id];
      expect(ids.length, greaterThan(1));

      final before = {
        for (final s in route.stops) s.id: (s.pickupTime, s.dropTime),
      };

      final reordered = await repo.reorderStops(
        query: query,
        request: ReorderTransportStopsRequest(
          routeId: route.id,
          stopOrder: ids.reversed.toList(),
        ),
      );

      for (final s in reordered.stops) {
        expect((s.pickupTime, s.dropTime), before[s.id],
            reason: 'resequencing must not drop stop times');
      }
      expect(
        [for (final s in reordered.stops) s.sequence],
        List<int>.generate(reordered.stops.length, (i) => i + 1),
        reason: 'sequence stays contiguous 1..n',
      );
    });
  });

  group('BUS-006 · TransportStop.hasNoTimes', () {
    test('true only when both times are blank', () {
      const base = TransportStop(
        id: 's',
        name: 'S',
        sequence: 1,
        pickupTime: '',
        dropTime: '',
        status: TransportStopStatus.upcoming,
        latitude: 0,
        longitude: 0,
      );
      expect(base.hasNoTimes, isTrue);
      expect(
        const TransportStop(
          id: 's',
          name: 'S',
          sequence: 1,
          pickupTime: '7:05 AM',
          dropTime: '',
          status: TransportStopStatus.upcoming,
          latitude: 0,
          longitude: 0,
        ).hasNoTimes,
        isFalse,
      );
    });
  });
}
