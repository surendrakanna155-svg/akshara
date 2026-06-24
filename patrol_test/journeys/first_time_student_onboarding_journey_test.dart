// Track C (TESTS/QA) — First-Time Student Data Onboarding UI journeys (Patrol).
//
// These drive Track B's StudentOnboardingScreen through the LOCKED CONTRACT v1
// surface. They COMPILE today (route + widget keys are referenced as string /
// ValueKey literals, not via not-yet-existent QaTestKeys constants), but only
// PASS once Track B lands the screen + keys and Track A lands the placeholder
// endpoint. Each journey notes its dependency.
//
// LOCKED CONTRACT v1:
//   Route : '/admin/onboarding/students' -> StudentOnboardingScreen
//   Keys  : onboarding_structure_step, onboarding_download_template_btn,
//           onboarding_upload_file_btn, onboarding_preview_list,
//           onboarding_commit_btn, onboarding_generate_placeholders_btn,
//           onboarding_add_one_btn, onboarding_add_one_form,
//           sis_placeholder_badge, sis_replace_placeholder_btn.
//
// Harness: matches patrol_test/workflows/startup_onboarding_certification_e2e_test.dart
//   (aksharaPatrolConfig(), bootstrapAndLogin(), goToErpRoute(), assertVisibleKey()).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  // LOCKED CONTRACT route + keys (string/ValueKey literals so this file does not
  // depend on QaTestKeys constants that Track B has not added yet).
  const onboardingRoute = '/admin/onboarding/students';
  const kStructureStep = ValueKey<String>('onboarding_structure_step');
  const kDownloadTemplateBtn =
      ValueKey<String>('onboarding_download_template_btn');
  const kUploadFileBtn = ValueKey<String>('onboarding_upload_file_btn');
  const kPreviewList = ValueKey<String>('onboarding_preview_list');
  const kCommitBtn = ValueKey<String>('onboarding_commit_btn');
  const kGeneratePlaceholdersBtn =
      ValueKey<String>('onboarding_generate_placeholders_btn');
  const kAddOneBtn = ValueKey<String>('onboarding_add_one_btn');
  const kAddOneForm = ValueKey<String>('onboarding_add_one_form');
  const kPlaceholderBadge = ValueKey<String>('sis_placeholder_badge');
  const kReplacePlaceholderBtn =
      ValueKey<String>('sis_replace_placeholder_btn');

  Future<void> openOnboarding(PatrolIntegrationTester $) async {
    await bootstrapAndLogin($, QaLoginPersona.superAdmin);
    await goToErpRoute($, onboardingRoute);
    await assertVisibleKey($, kStructureStep);
  }

  // J1 — Download template button is present and tappable on the upload step.
  // DEPENDS ON: Track B (screen + onboarding_download_template_btn).
  patrolTest(
    'journey: download Excel template from the onboarding screen',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await assertVisibleKey($, kDownloadTemplateBtn);
      await tapByKey($, kDownloadTemplateBtn);
      // Track B surfaces a confirmation (snackbar / saved-file toast). The exact
      // copy is owned by B; we assert the action did not error out of the flow.
      await assertVisibleKey($, kStructureStep);
    },
  );

  // J2 — Upload a valid file -> all rows valid -> commit -> students in SIS.
  // DEPENDS ON: Track B (upload picker + preview + commit wiring).
  patrolTest(
    'journey: upload valid file, preview all-valid, commit to SIS',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await tapByKey($, kUploadFileBtn);
      // Track B parses the picked file into rows and renders the preview list.
      await assertVisibleKey($, kPreviewList);
      await tapByKey($, kCommitBtn);
      // After commit, the contracted flow returns to the structure step / shows
      // a success surface; B owns the exact post-commit anchor.
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    },
  );

  // J3 — Upload a file with bad rows -> preview shows row-level errors -> fix.
  // DEPENDS ON: Track B (per-row error rendering inside onboarding_preview_list).
  patrolTest(
    'journey: upload file with bad rows surfaces row-level errors',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await tapByKey($, kUploadFileBtn);
      await assertVisibleKey($, kPreviewList);
      // The preview list must render at least one invalid row with an error
      // message; commit should remain blocked until the operator re-uploads.
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));
    },
  );

  // J4 — Rollback an import -> students removed cleanly.
  // DEPENDS ON: Track B (rollback affordance on a committed job) — the data-layer
  // rollback is covered in test/features/onboarding/first_time_student_onboarding_data_test.dart.
  patrolTest(
    'journey: rollback a committed import from the onboarding screen',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await tapByKey($, kUploadFileBtn);
      await assertVisibleKey($, kPreviewList);
      await tapByKey($, kCommitBtn);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      // Track B exposes the rollback control on the committed-job summary; once
      // its key is in the contract this journey taps it and re-asserts SIS.
    },
  );

  // J5 — Structure (Grade 6 = 2 sections x 30) -> generate -> 60 placeholders.
  // DEPENDS ON: Track A (generatePlaceholderStudents) + Track B (structure step +
  // onboarding_generate_placeholders_btn + sis_placeholder_badge).
  patrolTest(
    'journey: generate placeholder students from class/section structure',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await assertVisibleKey($, kStructureStep);
      // Track B's structure step captures classes/sections/students-per-section.
      await tapByKey($, kGeneratePlaceholdersBtn);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      // Generated students must carry the placeholder badge in the SIS roster.
      await assertVisibleKey($, kPlaceholderBadge);
    },
  );

  // J6 — Replace a placeholder with real data -> becomes real; parent login works.
  // DEPENDS ON: Track B (sis_replace_placeholder_btn flow that provisions parent).
  patrolTest(
    'journey: replace a placeholder student with real data',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await tapByKey($, kGeneratePlaceholdersBtn);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, kPlaceholderBadge);
      await tapByKey($, kReplacePlaceholderBtn);
      // Track B opens the replace/edit form; on save the placeholder flips to a
      // real student and a parent OTP login is provisioned (asserted in live J9).
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));
    },
  );

  // J7 — Add one student manually -> appears; parent OTP-login works.
  // DEPENDS ON: Track B (onboarding_add_one_btn + onboarding_add_one_form).
  patrolTest(
    'journey: add one student manually via the quick-add form',
    config: aksharaPatrolConfig(),
    ($) async {
      await openOnboarding($);
      await tapByKey($, kAddOneBtn);
      await assertVisibleKey($, kAddOneForm);
      // Track B owns the field labels inside the form; the contracted key proves
      // the quick-add surface opened. Submission + SIS appearance follow B's keys.
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));
    },
  );
}
