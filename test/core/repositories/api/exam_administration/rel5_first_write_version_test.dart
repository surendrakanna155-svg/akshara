import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/mapper/exam_mapper.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/remote/exam_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/exam_administration/remote/exam_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_dio_interceptor.dart';

/// REL-5 — first-write optimistic concurrency for the enforceable high-risk path
/// (per-cell exam mark update). The read model carries the persisted
/// `row_version`; the very first save sends it as `expectedVersion` so the
/// backend lost-update guard engages before any conflict/retry.
void main() {
  const query = RepositoryQuery.demo;
  const mapper = ExamMapper();

  group('REL-5 ExamMapper.toMark parses row_version', () {
    test('camelCase rowVersion', () {
      final mark = mapper.toMark(<String, dynamic>{
        'id': 'm1',
        'examId': 'e1',
        'marksObtained': 40,
        'rowVersion': 7,
      });
      expect(mark.rowVersion, 7);
    });

    test('snake_case row_version', () {
      final mark = mapper.toMark(<String, dynamic>{
        'id': 'm1',
        'examId': 'e1',
        'marksObtained': 40,
        'row_version': 3,
      });
      expect(mark.rowVersion, 3);
    });

    test('absent → null (legacy row, unconditional write)', () {
      final mark = mapper.toMark(<String, dynamic>{
        'id': 'm1',
        'examId': 'e1',
        'marksObtained': 40,
      });
      expect(mark.rowVersion, isNull);
    });
  });

  group('REL-5 updateMark sends expectedVersion on the FIRST write', () {
    late Map<String, dynamic> lastPatchBody;

    ExamRemoteDataSource buildDataSource() {
      return ExamRemoteDataSource(
        createFakeDio((options) {
          if (options.path.contains('/marks/') &&
              options.method.toUpperCase() == 'PATCH') {
            lastPatchBody = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
            return {
              'data': {
                'id': 'm1',
                'examId': 'e1',
                'marksObtained': lastPatchBody['marksObtained'],
                'published': false,
                'maxMarks': 80,
                'rowVersion': 8,
              },
            };
          }
          return {'data': <String, dynamic>{}};
        }),
      );
    }

    test('base row_version is forwarded as expectedVersion', () async {
      final ds = buildDataSource();
      final updated = await ds.updateMark(
        query: query,
        request: const UpdateExamMarkRequest(
          markEntryId: 'm1',
          marksObtained: 55,
          status: ExamMarkStatus.present,
          expectedVersion: 7,
        ),
      );
      expect(lastPatchBody['expectedVersion'], 7);
      expect(lastPatchBody['marksObtained'], 55);
      // The refreshed row carries the bumped version for the next edit.
      expect(updated.rowVersion, 8);
    });

    test('no version → no expectedVersion key (unconditional write)', () async {
      final ds = buildDataSource();
      await ds.updateMark(
        query: query,
        request: const UpdateExamMarkRequest(
          markEntryId: 'm1',
          marksObtained: 55,
        ),
      );
      expect(lastPatchBody.containsKey('expectedVersion'), isFalse);
    });

    test('markEntry path is the PATCH target', () {
      // Guards the wiring: the datasource PATCHes the single-cell endpoint.
      expect(ExamApiPaths.markEntry('m1'), contains('/marks/'));
    });
  });
}
