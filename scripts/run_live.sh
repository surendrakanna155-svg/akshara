#!/usr/bin/env bash
#
# Launch the Akshara app pointed at the LIVE backend on the VPS.
#
#   Live edge API:  https://akshara.veloraunisexsalon.com   (routes served at ROOT, no /v1)
#
# This only passes --dart-define values at runtime; it does NOT change any
# committed defaults. Without these defines the app still runs on local mocks.
#
# Usage:
#   scripts/run_live.sh                 # flutter run on default device
#   scripts/run_live.sh -d chrome       # pass extra flutter args through
#
# NOTE (auth, Batch 2 done): the live backend now sends real OTP SMS via Fast2SMS,
# rate-limits OTP requests, and no longer leaks the code in the response for the
# public. Only allowlisted PILOT phones (owner/testers, AUTH_OTP_PILOT_PHONES on
# the VPS) still get the OTP in the /auth/login response for instant, free login.
# Everyone else receives the code by SMS.

set -euo pipefail

LIVE_URL="https://akshara.veloraunisexsalon.com"

flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL="${LIVE_URL}" \
  --dart-define=ENABLE_API_MODE=true \
  --dart-define=AUTH_API_ENABLED=true \
  --dart-define=ADMISSIONS_API_ENABLED=true \
  --dart-define=SIS_API_ENABLED=true \
  --dart-define=ACADEMIC_API_ENABLED=true \
  --dart-define=EXAM_API_ENABLED=true \
  --dart-define=ATTENDANCE_API_ENABLED=true \
  --dart-define=APPROVAL_API_ENABLED=true \
  --dart-define=FINANCE_API_ENABLED=true \
  --dart-define=PAYMENT_API_ENABLED=true \
  --dart-define=HR_API_ENABLED=true \
  --dart-define=TRANSPORT_API_ENABLED=true \
  --dart-define=HOSTEL_API_ENABLED=true \
  --dart-define=LIBRARY_API_ENABLED=true \
  --dart-define=INVENTORY_API_ENABLED=true \
  --dart-define=INVENTORY_DISTRIBUTION_API_ENABLED=true \
  --dart-define=EMPLOYEE_API_ENABLED=true \
  --dart-define=MANAGEMENT_API_ENABLED=true \
  --dart-define=ALUMNI_API_ENABLED=true \
  --dart-define=PARENT_API_ENABLED=true \
  --dart-define=STUDENT_API_ENABLED=true \
  --dart-define=TEACHER_API_ENABLED=true \
  --dart-define=DIRECTOR_API_ENABLED=true \
  --dart-define=PREDICTIONS_API_ENABLED=true \
  "$@"
