// P0 remediation — SchoolGeofenceDataSource: the read/write seam for the FIRST
// gate of the attendance chain. Until a school stores a geofence, the server
// rejects EVERY check-in with STAFF_ATTENDANCE_GEOFENCE_NOT_CONFIGURED, so
// "404 means not configured (not an error)" and "the client never posts a
// payload the server would 422" are both load-bearing behaviours.
//
// Same mocked-Dio harness as face_enrollment_datasource_test.dart.

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/staff_attendance/geofence_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

class _RejectingInterceptor extends Interceptor {
  _RejectingInterceptor({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

Dio _rejectingDio({
  required int statusCode,
  Map<String, dynamic> body = const {},
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.api/v1'));
  dio.interceptors.add(_RejectingInterceptor(statusCode: statusCode, body: body));
  return dio;
}

const _query = RepositoryQuery.demo;

void main() {
  group('SchoolGeofence bounds mirror the server + DB CHECKs', () {
    const valid = SchoolGeofence(centerLatitude: 17.4, centerLongitude: 78.4);

    test('a well-formed config validates', () {
      expect(valid.validationError(), isNull);
    });

    test('radius outside 25..1000 is rejected at both ends', () {
      expect(valid.copyWith(radiusM: 24).validationError(), isNotNull);
      expect(valid.copyWith(radiusM: 1001).validationError(), isNotNull);
      expect(valid.copyWith(radiusM: 25).validationError(), isNull);
      expect(valid.copyWith(radiusM: 1000).validationError(), isNull);
    });

    test('accuracy limit outside 5..200 is rejected at both ends', () {
      expect(valid.copyWith(maxAccuracyM: 4).validationError(), isNotNull);
      expect(valid.copyWith(maxAccuracyM: 201).validationError(), isNotNull);
      expect(valid.copyWith(maxAccuracyM: 5).validationError(), isNull);
      expect(valid.copyWith(maxAccuracyM: 200).validationError(), isNull);
    });

    test('location-freshness window outside 10..600 is rejected — the server '
        'would silently substitute 60s, which would lie to the admin', () {
      expect(valid.copyWith(maxLocationAgeS: 9).validationError(), isNotNull);
      expect(valid.copyWith(maxLocationAgeS: 601).validationError(), isNotNull);
      expect(valid.copyWith(maxLocationAgeS: 10).validationError(), isNull);
    });

    test('out-of-range coordinates are rejected', () {
      expect(valid.copyWith(centerLatitude: 90.1).validationError(), isNotNull);
      expect(valid.copyWith(centerLongitude: -180.1).validationError(), isNotNull);
    });

    test('a NaN coordinate FAILS CLOSED — `!(x >= -90 && x <= 90)` rejects it '
        'where `x < -90 || x > 90` would let it through', () {
      expect(
        valid.copyWith(centerLatitude: double.nan).validationError(),
        isNotNull,
      );
      expect(
        valid.copyWith(centerLongitude: double.nan).validationError(),
        isNotNull,
      );
      expect(
        valid.copyWith(centerLatitude: double.infinity).validationError(),
        isNotNull,
      );
    });

    test('the design decision radii (50/100/150/200/300) are all valid', () {
      for (final radius in SchoolGeofence.radiusChoices) {
        expect(valid.copyWith(radiusM: radius).validationError(), isNull,
            reason: '$radius m must be selectable');
      }
    });
  });

  group('SchoolGeofenceDataSource.fetch', () {
    test('parses the scoped success envelope', () async {
      Map<String, dynamic>? capturedQuery;
      String? capturedMethod;
      String? capturedPath;

      final dio = createFakeDio((options) {
        capturedQuery = options.queryParameters;
        capturedMethod = options.method;
        capturedPath = options.path;
        return {
          'data': {
            'centerLatitude': 17.385,
            'centerLongitude': 78.4867,
            'radiusM': 150,
            'maxAccuracyM': 40,
            'maxLocationAgeS': 90,
          },
        };
      });

      final result =
          await SchoolGeofenceDataSource(dio: dio, query: _query).fetch();

      expect(capturedMethod, 'GET');
      expect(capturedPath, '/staff-attendance/geofence');
      expect(capturedQuery?['tenantId'], _query.tenantId);
      expect(capturedQuery?['schoolId'], _query.schoolId);
      expect(result, isNotNull);
      expect(result!.centerLatitude, 17.385);
      expect(result.centerLongitude, 78.4867);
      expect(result.radiusM, 150);
      expect(result.maxAccuracyM, 40);
      expect(result.maxLocationAgeS, 90);
    });

    test('accepts snake_case keys (server envelope drift tolerance)', () async {
      final dio = createFakeDio((_) => {
            'data': {
              'center_latitude': 12.5,
              'center_longitude': 77.5,
              'radius_m': 200,
              'max_accuracy_m': 60,
              'max_location_age_s': 120,
            },
          });

      final result =
          await SchoolGeofenceDataSource(dio: dio, query: _query).fetch();
      expect(result!.centerLatitude, 12.5);
      expect(result.radiusM, 200);
      expect(result.maxAccuracyM, 60);
      expect(result.maxLocationAgeS, 120);
    });

    test('a 404 GEOFENCE_NOT_CONFIGURED is null (a legitimate state), NOT a '
        'thrown error', () async {
      final dio = _rejectingDio(statusCode: 404, body: {
        'error': {
          'code': 'STAFF_ATTENDANCE_GEOFENCE_NOT_CONFIGURED',
          'message': 'Not configured',
        },
      });

      expect(
        await SchoolGeofenceDataSource(dio: dio, query: _query).fetch(),
        isNull,
      );
    });

    test('a 403 surfaces as a typed forbidden rejection', () async {
      final dio = _rejectingDio(statusCode: 403);

      await expectLater(
        () => SchoolGeofenceDataSource(dio: dio, query: _query).fetch(),
        throwsA(isA<SchoolGeofenceRejected>()
            .having((e) => e.isForbidden, 'isForbidden', isTrue)),
      );
    });
  });

  group('SchoolGeofenceDataSource.save', () {
    test('PUTs the full scoped config and parses the echoed envelope', () async {
      Map<String, dynamic>? capturedBody;
      String? capturedMethod;
      String? capturedPath;

      final dio = createFakeDio((options) {
        capturedBody = options.data as Map<String, dynamic>?;
        capturedMethod = options.method;
        capturedPath = options.path;
        return {'data': capturedBody};
      });

      final saved = await SchoolGeofenceDataSource(dio: dio, query: _query).save(
        const SchoolGeofence(
          centerLatitude: 17.385,
          centerLongitude: 78.4867,
          radiusM: 100,
          maxAccuracyM: 50,
          maxLocationAgeS: 60,
        ),
      );

      expect(capturedMethod, 'PUT');
      expect(capturedPath, '/staff-attendance/geofence');
      expect(capturedBody, {
        'centerLatitude': 17.385,
        'centerLongitude': 78.4867,
        'radiusM': 100,
        'maxAccuracyM': 50,
        'maxLocationAgeS': 60,
      });
      expect(saved.radiusM, 100);
    });

    test('an out-of-bounds config is refused CLIENT-side — no request is made',
        () async {
      var requested = false;
      final dio = createFakeDio((_) {
        requested = true;
        return {'data': <String, dynamic>{}};
      });

      await expectLater(
        () => SchoolGeofenceDataSource(dio: dio, query: _query).save(
          const SchoolGeofence(
            centerLatitude: 17.385,
            centerLongitude: 78.4867,
            radiusM: 5000,
          ),
        ),
        throwsA(isA<SchoolGeofenceRejected>().having(
          (e) => e.code,
          'code',
          'STAFF_ATTENDANCE_GEOFENCE_INVALID',
        )),
      );
      expect(requested, isFalse);
    });

    test('a 422 GEOFENCE_INVALID from the server surfaces typed', () async {
      final dio = _rejectingDio(statusCode: 422, body: {
        'error': {
          'code': 'STAFF_ATTENDANCE_GEOFENCE_INVALID',
          'message': 'radiusM must be 25..1000',
        },
      });

      await expectLater(
        () => SchoolGeofenceDataSource(dio: dio, query: _query).save(
          const SchoolGeofence(centerLatitude: 1, centerLongitude: 1),
        ),
        throwsA(isA<SchoolGeofenceRejected>()
            .having((e) => e.message, 'message', 'radiusM must be 25..1000')),
      );
    });

    test('a 403 (no manageSchoolGeofence) surfaces as forbidden, not a crash',
        () async {
      final dio = _rejectingDio(statusCode: 403);

      await expectLater(
        () => SchoolGeofenceDataSource(dio: dio, query: _query).save(
          const SchoolGeofence(centerLatitude: 1, centerLongitude: 1),
        ),
        throwsA(isA<SchoolGeofenceRejected>()
            .having((e) => e.isForbidden, 'isForbidden', isTrue)),
      );
    });
  });
}
