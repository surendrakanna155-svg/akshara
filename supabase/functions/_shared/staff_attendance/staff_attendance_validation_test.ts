// B4 — unit proof of the attendance auth chain math + gates (pure, DB-free).
// Anti-mock, high-accuracy, anti-stale, geofence distance, liveness + CV face match.

import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type GeofenceConfig,
  haversineMeters,
  parseStaffCheckBody,
  StaffAttendanceValidationError,
  validateLocation,
  verifyFace,
} from "./staff_attendance_validation.ts";
import {
  cosineSimilarity,
  DEFAULT_FACE_MATCH_THRESHOLD,
} from "../attendance_auth/face_match.ts";

const SCHOOL_LAT = 17.4500;
const SCHOOL_LNG = 78.3900;
const cfg: GeofenceConfig = {
  centerLatitude: SCHOOL_LAT,
  centerLongitude: SCHOOL_LNG,
  radiusM: 100,
  maxAccuracyM: 50,
  maxLocationAgeS: 60,
};
const NOW = Date.parse("2026-07-01T10:00:00Z");
const fresh = "2026-07-01T09:59:40Z"; // 20s old

function loc(over: Partial<Record<string, unknown>> = {}) {
  return {
    latitude: SCHOOL_LAT,
    longitude: SCHOOL_LNG,
    accuracyM: 8,
    isMock: false,
    capturedAt: fresh,
    ...over,
  } as Parameters<typeof validateLocation>[0];
}

Deno.test("haversine: same point is 0m; ~1 arc-minute lat ≈ 1.85km", () => {
  assertEquals(Math.round(haversineMeters(SCHOOL_LAT, SCHOOL_LNG, SCHOOL_LAT, SCHOOL_LNG)), 0);
  const km = haversineMeters(0, 0, 0, 1) / 1000; // 1° lng at equator ≈ 111.19km
  assert(km > 111 && km < 111.4, `got ${km}`);
});

Deno.test("cosineSimilarity (shared): identical=1, opposite=-1, mismatched dims fails closed to 0", () => {
  assertEquals(Math.round(cosineSimilarity([1, 0, 0], [1, 0, 0])), 1);
  assertEquals(Math.round(cosineSimilarity([1, 0], [-1, 0])), -1);
  assertEquals(cosineSimilarity([1, 2, 3], [1, 2]), 0);
});

Deno.test("verifyFace: dimension mismatch is a re-enrol error (FACE_EMBEDDING_MISMATCH), not FACE_NO_MATCH", () => {
  const e = assertThrows(
    () =>
      verifyFace(
        { embedding: [1, 2, 3], livenessPassed: true, captureRef: null, modelTag: "" },
        { embedding: [1, 2] },
      ),
    StaffAttendanceValidationError,
  );
  assertEquals((e as StaffAttendanceValidationError).code, "FACE_EMBEDDING_MISMATCH");
});

Deno.test("verifyFace: capture/enrollment model-tag mismatch is a re-enrol error; blank tags skip the check", () => {
  const ref = [0.9, 0.1, 0.2, 0.05];
  const e = assertThrows(
    () =>
      verifyFace(
        { embedding: ref, livenessPassed: true, captureRef: null, modelTag: "mobilefacenet-v2" },
        { embedding: ref, modelTag: "mobilefacenet-v1" },
      ),
    StaffAttendanceValidationError,
  );
  assertEquals((e as StaffAttendanceValidationError).code, "FACE_EMBEDDING_MISMATCH");
  // Legacy rows / captures without a tag: match proceeds on cosine alone.
  assert(verifyFace(
    { embedding: ref, livenessPassed: true, captureRef: null, modelTag: "" },
    { embedding: ref, modelTag: "mobilefacenet-v1" },
  ).matched);
});

Deno.test("validateLocation: passes inside geofence with a fresh, accurate, non-mock fix", () => {
  const v = validateLocation(loc(), cfg, NOW);
  assert(v.verified);
  assert(v.distanceM < 1);
});

Deno.test("validateLocation: MOCK location is rejected", () => {
  const e = assertThrows(() => validateLocation(loc({ isMock: true }), cfg, NOW), StaffAttendanceValidationError);
  assertEquals((e as StaffAttendanceValidationError).code, "MOCK_LOCATION");
});

Deno.test("validateLocation: LOW_ACCURACY fix is rejected", () => {
  const e = assertThrows(() => validateLocation(loc({ accuracyM: 120 }), cfg, NOW), StaffAttendanceValidationError);
  assertEquals((e as StaffAttendanceValidationError).code, "LOW_ACCURACY");
});

Deno.test("validateLocation: STALE fix (older than window) is rejected", () => {
  const e = assertThrows(
    () => validateLocation(loc({ capturedAt: "2026-07-01T09:58:00Z" }), cfg, NOW), // 120s old
    StaffAttendanceValidationError,
  );
  assertEquals((e as StaffAttendanceValidationError).code, "STALE_LOCATION");
});

Deno.test("validateLocation: OUTSIDE geofence (>100m away) is rejected", () => {
  // ~0.01° lat ≈ 1.1km north of school
  const e = assertThrows(
    () => validateLocation(loc({ latitude: SCHOOL_LAT + 0.01 }), cfg, NOW),
    StaffAttendanceValidationError,
  );
  assertEquals((e as StaffAttendanceValidationError).code, "OUTSIDE_GEOFENCE");
});

Deno.test("verifyFace: liveness must pass", () => {
  const ref = [1, 0, 0, 0];
  const e = assertThrows(
    () =>
      verifyFace(
        { embedding: ref, livenessPassed: false, captureRef: null, modelTag: "" },
        { embedding: ref },
      ),
    StaffAttendanceValidationError,
  );
  assertEquals((e as StaffAttendanceValidationError).code, "LIVENESS_FAILED");
});

Deno.test("verifyFace: matching face above threshold passes; a different face is rejected", () => {
  const ref = [0.9, 0.1, 0.2, 0.05];
  const same = verifyFace(
    { embedding: ref, livenessPassed: true, captureRef: null, modelTag: "" },
    { embedding: ref },
  );
  assert(same.matched);
  assert(same.score >= DEFAULT_FACE_MATCH_THRESHOLD);

  const e = assertThrows(
    () =>
      verifyFace(
        { embedding: [0.05, 0.9, 0.1, 0.9], livenessPassed: true, captureRef: null, modelTag: "" },
        { embedding: ref },
      ),
    StaffAttendanceValidationError,
  );
  assertEquals((e as StaffAttendanceValidationError).code, "FACE_NO_MATCH");
});

Deno.test("parseStaffCheckBody: rejects missing location / missing face; accepts a full body", () => {
  assertThrows(
    () => parseStaffCheckBody({ eventType: "check_in", face: { embedding: [1], livenessPassed: true } }),
    StaffAttendanceValidationError,
  );
  assertThrows(
    () => parseStaffCheckBody({ eventType: "check_in", location: loc() }),
    StaffAttendanceValidationError,
  );
  const ok = parseStaffCheckBody({
    eventType: "check_out",
    location: loc(),
    face: { embedding: [0.1, 0.2, 0.3], livenessPassed: true, captureRef: "cap/1.jpg" },
    staffName: "Asha",
  });
  assertEquals(ok.eventType, "check_out");
  assertEquals(ok.face.embedding.length, 3);
  assertEquals(ok.face.captureRef, "cap/1.jpg");
});
