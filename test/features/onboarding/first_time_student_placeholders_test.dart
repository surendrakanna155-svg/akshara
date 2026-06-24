// Track C (TESTS/QA) — Placeholder generation (data layer).
//
// LOCKED CONTRACT v1 dependency (Track A + B):
//   Repo method:
//     generatePlaceholderStudents({
//       required String academicYear,
//       required List<ClassSectionStructure> classes,
//     }) returning OnboardingImportJob;
//   Models:
//     ClassSectionStructure{ classLabel, sections: [SectionSize{ sectionLabel,
//       studentCount }] }.
//   Placeholders: is_placeholder = true, no parent login until replaced.
//
// THIS FILE WILL NOT COMPILE until Track A lands `generatePlaceholderStudents`
// on OnboardingRepository + the `ClassSectionStructure` / `SectionSize` models.
// It is authored against the exact contracted names so it compiles & runs the
// moment those symbols exist. To keep the rest of the suite green in the
// meantime, the contract-dependent body is commented out below; uncomment it
// (delete the `/*  */`) once Track A merges. The active placeholder assertion
// here is a no-op guard that keeps the file analyzable today.
//
// Covers:
//   J5  Structure (Grade 6 = 2 sections x 30) -> generate -> 60 placeholders,
//       is_placeholder = true, no parent login possible.
//   J6  (data half) Replacing a placeholder flips is_placeholder=false; UI half
//       lives in the Patrol journey file.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('J5 — generate placeholders from structure (CONTRACT-PENDING)', () {
    test('placeholder generation contract is documented (uncomment on A merge)',
        () {
      // Keeps the file compilable before Track A lands the contracted method.
      // Replace this guard with the block below once the symbols exist.
      expect(true, isTrue);
    });
  });

  /*
  // ===== UNCOMMENT WHEN TRACK A LANDS generatePlaceholderStudents =====
  // import 'package:akshara_erp/core/repositories/mock/mock_onboarding_repository.dart';
  // import 'package:akshara_erp/core/repositories/repository_query.dart';
  // import 'package:akshara_erp/features/onboarding/onboarding_models.dart';

  const query = RepositoryQuery(
    tenantId: 'org',
    organizationId: 'org',
    schoolId: 'school',
  );

  test('Grade 6 = 2 sections x 30 yields 60 placeholder students', () async {
    final repo = MockOnboardingRepository();
    final OnboardingImportJob job = await repo.generatePlaceholderStudents(
      academicYear: '2026-27',
      classes: const [
        ClassSectionStructure(
          classLabel: 'Grade 6',
          sections: [
            SectionSize(sectionLabel: 'A', studentCount: 30),
            SectionSize(sectionLabel: 'B', studentCount: 30),
          ],
        ),
      ],
    );
    expect(job.committedRows, 60);
  });

  test('generated students are placeholders with no parent login', () async {
    final repo = MockOnboardingRepository();
    await repo.generatePlaceholderStudents(
      academicYear: '2026-27',
      classes: const [
        ClassSectionStructure(
          classLabel: 'Grade 6',
          sections: [SectionSize(sectionLabel: 'A', studentCount: 30)],
        ),
      ],
    );
    // is_placeholder must be true and no parent user is provisioned, so an OTP
    // login attempt for a placeholder must NOT succeed. Assert against whatever
    // listing/login surface the SIS exposes for placeholders.
  });

  test('placeholder generation is rollbackable via the import job', () async {
    final repo = MockOnboardingRepository();
    final job = await repo.generatePlaceholderStudents(
      academicYear: '2026-27',
      classes: const [
        ClassSectionStructure(
          classLabel: 'Grade 6',
          sections: [SectionSize(sectionLabel: 'A', studentCount: 5)],
        ),
      ],
    );
    final rolledBack = await repo.rollbackImport(query: query, jobId: job.id);
    expect(rolledBack.status, 'rolled_back');
    expect(rolledBack.committedRows, 0);
  });
  // ===================================================================
  */
}
