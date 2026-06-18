import 'package:akshara_erp/core/repositories/api/phase4/api_phase4_repositories.dart';
import 'package:akshara_erp/core/repositories/api/phase4/phase4_mapper.dart';
import 'package:akshara_erp/core/repositories/api/phase4/phase4_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/sis/api_sis_repository.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_360_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/sis/sis_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/sis_id_crosswalk.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = SisFixtureBuilder();

void main() {
  group('F3 SIS + Student 360 API integration', () {
    late MockSisRepository mockSis;
    late MockStudent360Repository mock360;

    setUp(() {
      mockSis = MockSisRepository();
      mock360 = MockStudent360Repository();
    });

    test('ID crosswalk resolves mock SIS-STU-* to staging UUID', () {
      expect(
        SisIdCrosswalk.resolveToUuid('SIS-STU-10421'),
        SisIdCrosswalk.probeUuid,
      );
      expect(
        SisIdCrosswalk.mockIdForUuid(SisIdCrosswalk.probeUuid),
        'SIS-STU-10421',
      );
    });

    test('360 profile API parity exposes behaviour transport documents', () async {
      final mockProfile = await mock360.getProfile(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );

      final remote = Phase4RemoteDataSource(
        createFakeDio((options) {
          if (options.path.endsWith('/360')) {
            return {
              'data': {
                'studentId': SisIdCrosswalk.probeUuid,
                'profile': {
                  'identity': mockProfile.identity,
                  'admissions': mockProfile.admissions,
                  'attendance': mockProfile.attendance,
                  'marks': mockProfile.marks,
                  'homework': mockProfile.homework,
                  'communication': mockProfile.communication,
                  'fees': mockProfile.fees,
                  'inventory': mockProfile.inventory,
                  'activities': mockProfile.activities,
                  'achievements': mockProfile.achievements,
                  'risk': mockProfile.risk,
                  'parentInformation': mockProfile.parentInformation,
                  'behaviour': mockProfile.behaviour,
                  'transport': mockProfile.transport,
                  'documents': mockProfile.documents,
                },
              },
            };
          }
          return {'data': {}};
        }),
      );

      final repo = ApiStudent360Repository(remote: remote);
      final apiProfile = await repo.getProfile(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );

      expect(apiProfile.identity['displayName'], isNotNull);
      expect(apiProfile.behaviour['conductScore'], mockProfile.behaviour['conductScore']);
      expect(apiProfile.transport['routeName'], mockProfile.transport['routeName']);
      expect(apiProfile.documents['items'], isNotEmpty);
    });

    test('timeline API parity includes communication events', () async {
      final mockTimeline = await mock360.getTimeline(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );

      final remote = Phase4RemoteDataSource(
        createFakeDio((options) {
          if (options.path.endsWith('/timeline')) {
            return {
              'data': {
                'studentId': SisIdCrosswalk.probeUuid,
                'items': [
                  for (final event in mockTimeline)
                    {
                      'id': event.id,
                      'eventType': event.eventType,
                      'eventAt': event.eventAt,
                      'title': event.title,
                      'summary': event.summary,
                      'sourceModule': event.sourceModule,
                      'payload': event.payload,
                    },
                ],
              },
            };
          }
          return {'data': {}};
        }),
      );

      final repo = ApiStudent360Repository(remote: remote);
      final apiTimeline = await repo.getTimeline(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );

      expect(apiTimeline.length, mockTimeline.length);
      expect(
        apiTimeline.any((event) => event.sourceModule == 'communication'),
        isTrue,
      );
    });

    test('student profile maps server documents array', () async {
      final mockProfile = await mockSis.getStudentProfile(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );

      final remote = SisRemoteDataSource(
        createFakeDio((options) {
          if (options.path == SisApiPaths.studentProfile('SIS-STU-10421')) {
            return _fixtures.profileEnvelope(mockProfile);
          }
          return {'data': {}};
        }),
      );

      final repo = ApiSisRepository(remote: remote);
      final apiProfile = await repo.getStudentProfile(
        query: kQuery,
        studentId: 'SIS-STU-10421',
      );

      expect(apiProfile.documents.length, mockProfile.documents.length);
    });

    test('Phase4Mapper normalizes identity name aliases', () {
      final profile = Phase4Mapper.student360FromApi({
        'profile': {
          'identity': {'name': 'Arjun Reddy'},
          'attendance': {},
          'marks': {},
          'homework': {},
          'communication': {},
          'fees': {},
          'inventory': {},
          'activities': {},
          'achievements': {},
          'risk': {},
          'parentInformation': {},
          'behaviour': {},
          'transport': {},
          'documents': {},
        },
      });
      expect(profile.identity['displayName'], 'Arjun Reddy');
      expect(profile.identity['name'], 'Arjun Reddy');
    });
  });
}
