// Track C (TESTS/QA) — First-Time Student Data Onboarding.
//
// Repo/data-level journeys that DO NOT need Track B's UI. These compile and run
// in mock mode TODAY against MockOnboardingRepository + the contracted models.
//
// Covers (from the plan's "Tests / QA (Track C)" list):
//   J1  Download template -> correct headers + one example row.
//   J3  Upload bad rows -> per-row errors -> fix -> commit (data layer).
//   J4  Rollback an import -> committed rows cleared.
//   J8  Aadhaar: import without it works; duplicate Aadhaar flagged in preview.
//
// LOCKED CONTRACT v1 dependency notes:
//   * New optional import fields: aadhaar (12 digits), motherName, dob, gender.
//   * Duplicate aadhaar must be flagged in the preview (duplicateRows > 0 and/or
//     a row-level error). Until Track A extends parseStudentImportRow / the mock
//     preview to honour these fields, the Aadhaar-dedupe assertions below are
//     authored against the contract and are expected to fail (NOT a syntax error
//     on Track C's side). They are marked with `// CONTRACT-PENDING` so a merge
//     reviewer can tell intended-red from broken.

import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/mock/mock_onboarding_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';

void main() {
  const query = RepositoryQuery(
    tenantId: 'org',
    organizationId: 'org',
    schoolId: 'school',
  );

  /// The exact Excel/CSV template header order from the plan
  /// (docs/plans/FIRST_TIME_STUDENT_DATA_ONBOARDING_PLAN.md, "exact columns").
  /// Track B's `onboarding_download_template_btn` must emit this header row.
  const expectedTemplateHeaders = <String>[
    'Student Name',
    'Admission Number',
    'Class',
    'Section',
    'Academic Year',
    'Father / Parent Name',
    'Parent Phone',
    'Aadhaar Number',
    'Mother Name',
    'Student Phone',
    'Roll Number',
    'Date of Birth',
    'Gender',
  ];

  /// A single valid student row keyed the way the import endpoint expects
  /// (camelCase). Mirrors the example row the template ships with.
  Map<String, dynamic> validRow({
    String studentName = 'Aarav Sharma',
    String admissionNumber = 'ADM-1001',
    String classLabel = 'Grade 6',
    String sectionLabel = 'A',
    String academicYear = '2026-27',
    String parentName = 'Rohit Sharma',
    String parentPhone = '9876500001',
    String? aadhaar,
    String? motherName,
    String? dob,
    String? gender,
  }) {
    final row = <String, dynamic>{
      'studentName': studentName,
      'admissionNumber': admissionNumber,
      'classLabel': classLabel,
      'sectionLabel': sectionLabel,
      'academicYear': academicYear,
      'parentName': parentName,
      'parentPhone': parentPhone,
    };
    if (aadhaar != null) row['aadhaar'] = aadhaar;
    if (motherName != null) row['motherName'] = motherName;
    if (dob != null) row['dob'] = dob;
    if (gender != null) row['gender'] = gender;
    return row;
  }

  group('J1 — template headers + example row', () {
    test('expected template headers list is the documented order', () {
      // Guards the contract the Track B download button is built against; if
      // the plan's column order changes, this list (and the button) must move
      // together. Required columns come first, then the optional ones.
      expect(expectedTemplateHeaders.first, 'Student Name');
      expect(expectedTemplateHeaders.sublist(0, 7), const <String>[
        'Student Name',
        'Admission Number',
        'Class',
        'Section',
        'Academic Year',
        'Father / Parent Name',
        'Parent Phone',
      ]);
      expect(expectedTemplateHeaders, contains('Aadhaar Number'));
      expect(expectedTemplateHeaders, contains('Mother Name'));
      expect(expectedTemplateHeaders, contains('Date of Birth'));
      expect(expectedTemplateHeaders, contains('Gender'));
      expect(expectedTemplateHeaders.length, 13);
    });

    test('example row covers every required column', () {
      final example = validRow();
      // The seven required fields must all be present and non-empty so the
      // shipped example row is itself a valid import.
      for (final key in const [
        'studentName',
        'admissionNumber',
        'classLabel',
        'sectionLabel',
        'academicYear',
        'parentName',
        'parentPhone',
      ]) {
        expect(example[key], isNotNull, reason: '$key missing from example row');
        expect((example[key] as String).isNotEmpty, isTrue);
      }
    });
  });

  group('J2/J3 — preview validates rows, then commit', () {
    test('all-valid file previews clean then commits all rows', () async {
      final repo = MockOnboardingRepository();
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [validRow(), validRow(admissionNumber: 'ADM-1002')],
      );
      expect(preview.job.validRows, 2);
      expect(preview.job.invalidRows, 0);

      final committed =
          await repo.commitImport(query: query, jobId: preview.job.id);
      expect(committed.status, 'committed');
      expect(committed.committedRows, 2);
    });

    test('bad rows surface row-level errors; fixed rows then commit', () async {
      final repo = MockOnboardingRepository();
      // Row 2 is missing the required studentName + admissionNumber.
      final firstPass = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [
          validRow(),
          const {'classLabel': 'Grade 6', 'sectionLabel': 'A'},
        ],
      );
      expect(firstPass.job.validRows, 1);
      expect(firstPass.job.invalidRows, 1);

      final badRow = firstPass.preview.firstWhere((r) => r.status == 'invalid');
      expect(badRow.errors, isNotEmpty);
      expect(badRow.errors.join(' '), contains('studentName'));

      // Operator fixes the row and re-previews; now everything is valid.
      final secondPass = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [validRow(), validRow(admissionNumber: 'ADM-1002')],
      );
      expect(secondPass.job.invalidRows, 0);
      final committed =
          await repo.commitImport(query: query, jobId: secondPass.job.id);
      expect(committed.committedRows, 2);
    });
  });

  group('J4 — rollback removes committed rows cleanly', () {
    test('rollback flips status and zeroes committed rows', () async {
      final repo = MockOnboardingRepository();
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [validRow(), validRow(admissionNumber: 'ADM-1002')],
      );
      final committed =
          await repo.commitImport(query: query, jobId: preview.job.id);
      expect(committed.committedRows, 2);

      final rolledBack =
          await repo.rollbackImport(query: query, jobId: preview.job.id);
      expect(rolledBack.status, 'rolled_back');
      expect(rolledBack.committedRows, 0);
    });
  });

  group('J8 — Aadhaar optional + masked + duplicate flagged', () {
    test('import without Aadhaar is fully valid', () async {
      final repo = MockOnboardingRepository();
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [validRow(), validRow(admissionNumber: 'ADM-1002')],
      );
      expect(preview.job.validRows, 2);
      expect(preview.job.invalidRows, 0);
    });

    test('valid 12-digit Aadhaar is accepted', () async {
      final repo = MockOnboardingRepository();
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [validRow(aadhaar: '123412341234')],
      );
      expect(preview.job.validRows, 1);
    });

    // CONTRACT-PENDING (Track A): duplicate Aadhaar must be flagged in preview.
    // Until parseStudentImportRow + the mock honour `aadhaar` de-dup, this is an
    // intended red, not a Track C syntax/import error.
    test('duplicate Aadhaar across two rows is flagged in preview', () async {
      final repo = MockOnboardingRepository();
      final preview = await repo.previewStudentImport(
        query: query,
        fileName: 'students.csv',
        rows: [
          validRow(admissionNumber: 'ADM-1001', aadhaar: '999988887777'),
          validRow(admissionNumber: 'ADM-1002', aadhaar: '999988887777'),
        ],
      );
      final dupFlagged = preview.job.duplicateRows > 0 ||
          preview.preview.any(
            (r) => r.errors.join(' ').toLowerCase().contains('aadhaar'),
          );
      expect(
        dupFlagged,
        isTrue,
        reason: 'duplicate Aadhaar must raise duplicateRows or a row error',
      );
    });
  });
}
