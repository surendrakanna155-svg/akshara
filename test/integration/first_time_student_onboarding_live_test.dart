// Track C (TESTS/QA) — LIVE-MODE first-time student onboarding (Journey 9).
//
// Live versions of the high-value journeys 2, 5, 7, run against the real
// Supabase backend. Gated behind a dart-define flag exactly like the existing
// test/integration/auth_staging_integration_test.dart (RUN_STAGING_AUTH_TEST):
// when the flag is absent these are skipped with a single green placeholder so
// the default `flutter test` run stays mock-only.
//
// Run (against the live VPS backend):
//   flutter test test/integration/first_time_student_onboarding_live_test.dart \
//     --dart-define=RUN_LIVE_ONBOARDING_TEST=true \
//     --dart-define=API_BASE_URL=https://akshara.veloraunisexsalon.com/functions/v1/api \
//     --dart-define=LIVE_TENANT_ID=<tenant> \
//     --dart-define=LIVE_SCHOOL_ID=<school> \
//     --dart-define=LIVE_ORG_ID=<org> \
//     --dart-define=LIVE_PARENT_PHONE=<10-15 digit phone in pilot allowlist>
//
// REQUIRES THE LIVE BACKEND. Do not run in CI without the flag + a seeded,
// allowlisted pilot tenant — these create real students and a real parent user.
//
// CONTRACT-PENDING (Track A): J5-live calls generatePlaceholderStudents, which
// does not exist on the API repository yet. That block is commented out and
// referenced by exact contracted name so it activates on Track A merge.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/api/admissions/dto/api_envelope_dto.dart';

void main() {
  const runLive = bool.fromEnvironment('RUN_LIVE_ONBOARDING_TEST');
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  const tenantId = String.fromEnvironment('LIVE_TENANT_ID');
  const schoolId = String.fromEnvironment('LIVE_SCHOOL_ID');
  const orgId = String.fromEnvironment('LIVE_ORG_ID');
  const parentPhone = String.fromEnvironment(
    'LIVE_PARENT_PHONE',
    defaultValue: '9876500099',
  );

  if (!runLive) {
    test('live onboarding skipped without RUN_LIVE_ONBOARDING_TEST', () {
      expect(true, isTrue);
    });
    return;
  }

  late Dio dio;

  setUp(() {
    if (baseUrl.isEmpty) {
      fail('API_BASE_URL dart-define is required for the live onboarding test');
    }
    if (tenantId.isEmpty || schoolId.isEmpty || orgId.isEmpty) {
      fail('LIVE_TENANT_ID / LIVE_SCHOOL_ID / LIVE_ORG_ID dart-defines required');
    }
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'x-tenant-id': tenantId,
        'x-school-id': schoolId,
        'x-organization-id': orgId,
      },
    ));
  });

  // A valid student row keyed as the live import endpoint expects.
  Map<String, dynamic> liveRow({
    required String admissionNumber,
    String? aadhaar,
  }) {
    final row = <String, dynamic>{
      'studentName': 'Live QA $admissionNumber',
      'admissionNumber': admissionNumber,
      'classLabel': 'Grade 6',
      'sectionLabel': 'A',
      'academicYear': '2026-27',
      'parentName': 'Live QA Parent',
      'parentPhone': parentPhone,
    };
    if (aadhaar != null) row['aadhaar'] = aadhaar;
    return row;
  }

  group('Journey 9 — live backend onboarding', () {
    test('backend health endpoint is reachable', () async {
      final response = await dio.get<Map<String, dynamic>>('/health');
      final envelope = ApiEnvelopeDto.fromJson(response.data ?? {});
      expect(envelope.requireData()['status'], 'ok');
    });

    // J2-live: preview valid rows -> commit -> rollback to keep the tenant clean.
    test('upload valid rows, preview, commit, then rollback', () async {
      final unique = DateTime.now().millisecondsSinceEpoch;
      final previewResp = await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/students/preview',
        data: {
          'fileName': 'live_qa.csv',
          'rows': [liveRow(admissionNumber: 'LIVE-$unique')],
        },
      );
      final preview = ApiEnvelopeDto.fromJson(previewResp.data ?? {});
      final job = preview.requireData()['job'] as Map<String, dynamic>;
      expect(job['validRows'], 1);
      final jobId = job['id'] as String;

      final commitResp = await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/$jobId/commit',
      );
      final commit = ApiEnvelopeDto.fromJson(commitResp.data ?? {});
      expect(commit.requireData()['status'], 'committed');

      // Committing upserts the parent user -> the parent can now OTP-login.
      // (OTP verification path is exercised by auth_staging_integration_test.)

      // Clean up so repeated live runs do not accrete students.
      final rollbackResp = await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/$jobId/rollback',
      );
      final rollback = ApiEnvelopeDto.fromJson(rollbackResp.data ?? {});
      expect(rollback.requireData()['status'], 'rolled_back');
    }, timeout: const Timeout(Duration(minutes: 2)));

    // J7-live: add one student manually via the single-row import path.
    test('add one student via single-row import, then rollback', () async {
      final unique = DateTime.now().millisecondsSinceEpoch;
      final previewResp = await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/students/preview',
        data: {
          'fileName': 'live_qa_add_one.csv',
          'rows': [liveRow(admissionNumber: 'LIVE-ONE-$unique')],
        },
      );
      final preview = ApiEnvelopeDto.fromJson(previewResp.data ?? {});
      final job = preview.requireData()['job'] as Map<String, dynamic>;
      expect(job['validRows'], 1);
      final jobId = job['id'] as String;

      final commitResp = await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/$jobId/commit',
      );
      expect(
        ApiEnvelopeDto.fromJson(commitResp.data ?? {})
            .requireData()['status'],
        'committed',
      );

      await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/$jobId/rollback',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    // J5-live: structure -> generate placeholders -> assert no parent login.
    // CONTRACT-PENDING (Track A): the /onboarding/students/generate endpoint.
    /*
    test('generate placeholders from structure, assert no parent login', () async {
      final genResp = await dio.post<Map<String, dynamic>>(
        '/onboarding/students/generate',
        data: {
          'academicYear': '2026-27',
          'classes': [
            {
              'classLabel': 'Grade 6',
              'sections': [
                {'sectionLabel': 'A', 'studentCount': 30},
                {'sectionLabel': 'B', 'studentCount': 30},
              ],
            },
          ],
        },
      );
      final gen = ApiEnvelopeDto.fromJson(genResp.data ?? {});
      final job = gen.requireData()['job'] as Map<String, dynamic>;
      expect(job['committedRows'], 60);
      // Placeholders carry is_placeholder=true and provision NO parent user, so
      // an OTP login for a placeholder's (absent) phone must fail. Roll back to
      // keep the tenant clean.
      final jobId = job['id'] as String;
      await dio.post<Map<String, dynamic>>(
        '/onboarding/imports/$jobId/rollback',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
    */
  });
}
