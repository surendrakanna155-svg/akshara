import 'package:akshara_erp/core/repositories/api/phase4/api_phase4_repositories.dart';
import 'package:akshara_erp/core/repositories/api/phase4/phase4_mapper.dart';
import 'package:akshara_erp/core/repositories/api/phase4/phase4_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_360_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Student 360 repository contract', () {
    final mock = MockStudent360Repository();

    test('mock profile exposes pilot dossier domains', () async {
      final profile = await mock.getProfile(query: query, studentId: 'student_1');
      expect(profile.identity['displayName'], isNotNull);
      expect(profile.attendance, isNotEmpty);
      expect(profile.marks, isNotEmpty);
      expect(profile.behaviour, isNotEmpty);
      expect(profile.transport, isNotEmpty);
      expect(profile.documents, isNotEmpty);
    });

    test('API mapper maps dossier domains from envelope', () {
      final profile = Phase4Mapper.student360FromApi({
        'identity': {
          'studentId': 'SIS-STU-10418',
          'displayName': 'Arjun Reddy',
          'className': 'Grade 8',
          'sectionName': 'A',
        },
        'attendance': {'present': 40, 'absent': 2, 'percent': 95},
        'marks': {'exams': []},
        'homework': {'submitted': 5, 'total': 6},
        'fees': {'paidPercent': 80},
        'communication': {},
        'behaviour': {'conductScore': 90},
        'transport': {'routeName': 'Route 1'},
        'documents': {'items': []},
        'parentInformation': {'guardians': []},
        'risk': {'riskLevel': 'low'},
      });
      expect(profile.identity['displayName'], 'Arjun Reddy');
      expect(profile.behaviour['conductScore'], 90);
      expect(profile.transport['routeName'], 'Route 1');
    });

    test('API repository maps 360 dossier via fake Dio', () async {
      final mockProfile = await mock.getProfile(query: query, studentId: 'student_1');
      final repo = ApiStudent360Repository(
        remote: Phase4RemoteDataSource(
          createFakeDio((options) {
            return {
              'data': {
                'studentId': 'student_1',
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
          }),
        ),
      );

      final profile = await repo.getProfile(query: query, studentId: 'student_1');
      expect(profile.behaviour['conductScore'], mockProfile.behaviour['conductScore']);
      expect(profile.transport['routeName'], mockProfile.transport['routeName']);
    });

    test('mock timeline returns ordered events', () async {
      final timeline = await mock.getTimeline(query: query, studentId: 'student_1');
      expect(timeline, isNotEmpty);
      expect(timeline.first.eventType, isNotEmpty);
    });
  });
}
