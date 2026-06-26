import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/api/education/mapper/education_mapper.dart';

// AI-5 (Wave 4): the composition chips (bank-reuse / AI-generated) are persisted
// inside `blueprint` (with the AI count stored as `aiCandidateCount`); only the
// generate response echoes them at the top level. The summary mapper must read
// either shape so the chips no longer always show 0.
void main() {
  Map<String, dynamic> baseJson() => {
        'id': 'paper-1',
        'title': 'Unit Test 1',
        'className': '10',
        'subjectName': 'Mathematics',
        'examType': 'unit_test',
        'totalMarks': 20,
        'difficulty': 'mixed',
        'status': 'draft',
        'reviewStatus': 'draft',
        'programTrack': 'board',
      };

  test('reads composition counts from blueprint', () {
    final json = baseJson()
      ..['blueprint'] = {
        'bankReuseCount': 7,
        'aiCandidateCount': 3,
      };

    final summary = EducationMapper.paperSummaryFromApi(json);

    expect(summary.bankReuseCount, 7);
    expect(summary.aiGeneratedCount, 3);
  });

  test('prefers top-level counts when present (generate response)', () {
    final json = baseJson()
      ..['bankReuseCount'] = 9
      ..['aiGeneratedCount'] = 2
      ..['blueprint'] = {'bankReuseCount': 0, 'aiCandidateCount': 0};

    final summary = EducationMapper.paperSummaryFromApi(json);

    expect(summary.bankReuseCount, 9);
    expect(summary.aiGeneratedCount, 2);
  });

  test('tolerates missing blueprint and numeric doubles', () {
    final noBlueprint = EducationMapper.paperSummaryFromApi(baseJson());
    expect(noBlueprint.bankReuseCount, isNull);
    expect(noBlueprint.aiGeneratedCount, isNull);

    final doubles = EducationMapper.paperSummaryFromApi(
      baseJson()..['blueprint'] = {'bankReuseCount': 5.0, 'aiCandidateCount': 1.0},
    );
    expect(doubles.bankReuseCount, 5);
    expect(doubles.aiGeneratedCount, 1);
  });
}
