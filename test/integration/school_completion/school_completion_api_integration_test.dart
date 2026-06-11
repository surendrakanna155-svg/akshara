import 'package:akshara_erp/core/repositories/api/school_completion/api_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/api/school_completion/remote/school_completion_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/school_completion/remote/school_completion_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('School Completion API integration', () {
    late MockSchoolCompletionRepository mockRepo;
    late ApiSchoolCompletionRepository apiRepo;

    setUp(() async {
      mockRepo = MockSchoolCompletionRepository();
      final subjects = await mockRepo.listSubjects(query: kQuery);
      final branding = await mockRepo.getBranding(query: kQuery);

      final dio = createFakeDio((options) {
        if (options.path == SchoolCompletionApiPaths.subjects) {
          return {
            'data': {
              'items': subjects
                  .map(
                    (s) => {
                      'id': s.id,
                      'subjectCode': s.subjectCode,
                      'subjectName': s.subjectName,
                      'category': s.category,
                      'gradeLabels': s.gradeLabels,
                      'status': s.status,
                    },
                  )
                  .toList(),
            },
          };
        }
        if (options.path == SchoolCompletionApiPaths.branding) {
          return {
            'data': {
              'displayName': branding.displayName,
              'tagline': branding.tagline,
              'primaryColor': branding.primaryColor,
              'secondaryColor': branding.secondaryColor,
            },
          };
        }
        return {'data': {}};
      });

      apiRepo = ApiSchoolCompletionRepository(
        remote: SchoolCompletionRemoteDataSource(dio),
      );
    });

    test('listSubjects maps API items', () async {
      final items = await apiRepo.listSubjects(query: kQuery);
      expect(items.length, greaterThanOrEqualTo(3));
    });

    test('getBranding maps API payload', () async {
      final branding = await apiRepo.getBranding(query: kQuery);
      expect(branding.displayName, isNotEmpty);
    });
  });
}
