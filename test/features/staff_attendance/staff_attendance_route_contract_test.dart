// Client→server route contract for the staff-attendance family.
//
// WHY THIS EXISTS. The manual-attendance approver queue shipped calling
// `GET /staff-attendance/manual-request` — SINGULAR. The server registers the
// singular path for POST only; the list is `GET /staff-attendance/manual-requests`
// (PLURAL). So the queue 404'd for every approver, and the design's only
// sanctioned fallback when the geofence+face chain cannot complete was dead.
//
// Every existing test passed, because they all inject a fake at the DataSource
// interface — one level ABOVE the URL. A seam mocked above the bug can never
// see the bug. This test closes that gap from the other side: it drives the
// REAL datasources through a recording Dio and asserts each (method, path) they
// emit is actually registered in `staff_attendance_router.ts`.
//
// It deliberately asserts ROUTING ONLY. Payload shapes are covered by the
// per-datasource tests, so the canned response here is intentionally empty and
// parse failures are ignored — the request has already been recorded by then.

import 'dart:io';

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/staff_attendance/geofence_datasource.dart';
import 'package:akshara_erp/features/staff_attendance/manual_attendance_request_datasource.dart';
import 'package:akshara_erp/features/staff_attendance/manual_request_datasource.dart'
    as slice4;
import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

/// A (method, path) pair as the router matches it.
typedef _Call = ({String method, String path});

class _RecordingInterceptor extends Interceptor {
  _RecordingInterceptor(this.calls);
  final List<_Call> calls;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls.add((method: options.method.toUpperCase(), path: options.path));
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: const <String, dynamic>{'data': <String, dynamic>{}},
      ),
    );
  }
}

/// The routes `staff_attendance_router.ts` actually dispatches, parsed from the
/// router itself. Reading the source rather than restating it is the point: a
/// hand-copied list would drift exactly like the client did.
Set<_Call> _registeredRoutes() {
  final file = File(
    'supabase/functions/_shared/staff_attendance/staff_attendance_router.ts',
  );
  expect(
    file.existsSync(),
    isTrue,
    reason: 'router moved — update this path or the contract stops being checked',
  );
  final pattern = RegExp(
    r'path === "([^"]+)"\s*&&\s*method === "([A-Z]+)"',
  );
  final routes = <_Call>{
    for (final m in pattern.allMatches(file.readAsStringSync()))
      (method: m.group(2)!, path: m.group(1)!),
  };
  expect(
    routes,
    isNotEmpty,
    reason: 'parsed no routes — the router style changed and this test went blind',
  );
  return routes;
}

/// Drives [body] against a recording Dio and returns everything it requested.
Future<List<_Call>> _capture(Future<void> Function(Dio dio) body) async {
  final calls = <_Call>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://test.api/v1'))
    ..interceptors.add(_RecordingInterceptor(calls));
  try {
    await body(dio);
  } on Object {
    // Parsing an empty envelope may throw; the call is already recorded.
  }
  return calls;
}

void main() {
  late Set<_Call> registered;

  setUpAll(() => registered = _registeredRoutes());

  void expectRegistered(List<_Call> calls) {
    expect(calls, isNotEmpty, reason: 'no request was issued at all');
    for (final call in calls) {
      expect(
        registered.contains(call),
        isTrue,
        reason: '${call.method} ${call.path} is not routed by the server. '
            'Registered: ${registered.map((r) => '${r.method} ${r.path}').toList()..sort()}',
      );
    }
  }

  group('manual-attendance request datasource hits real routes', () {
    ManualAttendanceRequestRemoteDataSource source(Dio dio) =>
        ManualAttendanceRequestRemoteDataSource(dio: dio, query: _query);

    test('the approver queue reads the PLURAL list route', () async {
      final calls = await _capture((dio) => source(dio).listPending());
      // The exact regression: singular here 404s for every approver.
      expect(
        calls.single,
        (method: 'GET', path: '/staff-attendance/manual-requests'),
      );
      expectRegistered(calls);
    });

    test('raising a request posts the SINGULAR route', () async {
      final calls = await _capture(
        (dio) => source(dio).submit(
          event: StaffCheckEvent.checkIn,
          reason: 'Face capture unavailable at the gate',
        ),
      );
      expect(
        calls.single,
        (method: 'POST', path: '/staff-attendance/manual-request'),
      );
      expectRegistered(calls);
    });

    test('deciding posts the decide route', () async {
      final calls = await _capture(
        (dio) => source(dio).decide(requestId: 'req-1', approve: true),
      );
      expectRegistered(calls);
    });
  });

  group('slice-4 manual-request datasource hits real routes', () {
    slice4.ManualAttendanceRequestDataSource source(Dio dio) =>
        slice4.ManualAttendanceRequestDataSource(dio: dio, query: _query);

    test('create / myRequests / pendingQueue / decide are all routed',
        () async {
      expectRegistered(
        await _capture(
          (dio) => source(dio)
              .create(event: StaffCheckEvent.checkIn, reason: 'gate camera down'),
        ),
      );
      expectRegistered(await _capture((dio) => source(dio).myRequests()));
      expectRegistered(await _capture((dio) => source(dio).pendingQueue()));
      expectRegistered(
        await _capture(
          (dio) => source(dio).decide(requestId: 'req-1', approve: false),
        ),
      );
    });
  });

  group('geofence datasource hits real routes', () {
    SchoolGeofenceDataSource source(Dio dio) =>
        SchoolGeofenceDataSource(dio: dio, query: _query);

    test('read and write both routed', () async {
      expectRegistered(await _capture((dio) => source(dio).fetch()));
      expectRegistered(
        await _capture(
          (dio) => source(dio).save(
            const SchoolGeofence(centerLatitude: 17.4, centerLongitude: 78.4),
          ),
        ),
      );
    });
  });
}
