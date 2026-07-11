// B4 — staff attendance auth: pure validation + geo/face math (no I/O, unit-testable).
// The attendance chain per docs/ATTENDANCE_AUTH_DESIGN_DECISION.md (FINAL):
//   GPS geofence -> anti-mock/high-accuracy/anti-stale location -> live camera
//   face verification (server-authoritative CV match vs enrolled reference).
// Device biometric is NOT part of this chain (login-only).

import { cosineSimilarity, faceMatchThreshold } from "../attendance_auth/face_match.ts";

export type StaffCheckEventType = "check_in" | "check_out";
const EVENT_TYPES: readonly StaffCheckEventType[] = ["check_in", "check_out"];

export class StaffAttendanceValidationError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = "StaffAttendanceValidationError";
    this.code = code;
  }
}

export interface AttendanceLocation {
  latitude: number;
  longitude: number;
  accuracyM: number;
  isMock: boolean;
  capturedAt: string; // ISO-8601
}

export interface AttendanceFace {
  embedding: number[];
  livenessPassed: boolean;
  captureRef: string | null;
  /** Which on-device model produced the live embedding (e.g. mobilefacenet-v1).
   * Compared against the enrolled reference's model_tag when both are set —
   * cross-model cosine scores are meaningless, so a mismatch must be a
   * re-enrol error, not a confusing FACE_NO_MATCH. */
  modelTag: string;
}

export interface ParsedStaffCheck {
  eventType: StaffCheckEventType;
  location: AttendanceLocation;
  face: AttendanceFace;
  staffName: string;
  employeeRef: string | null;
}

export interface GeofenceConfig {
  centerLatitude: number;
  centerLongitude: number;
  radiusM: number;
  maxAccuracyM: number;
  maxLocationAgeS: number;
}

/** Great-circle distance in metres (Haversine). */
export function haversineMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371000; // earth radius, metres
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}

function num(v: unknown): number | null {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

/** Parse + shape-validate the request body. Throws with a specific code on bad shape. */
export function parseStaffCheckBody(
  body: Record<string, unknown> | null,
): ParsedStaffCheck {
  if (!body) throw new StaffAttendanceValidationError("BODY_REQUIRED", "JSON body required");

  const eventTypeRaw = String(body.eventType ?? body.event_type ?? "").trim();
  if (!EVENT_TYPES.includes(eventTypeRaw as StaffCheckEventType)) {
    throw new StaffAttendanceValidationError(
      "INVALID_EVENT_TYPE",
      `eventType must be one of ${EVENT_TYPES.join(", ")}`,
    );
  }

  const loc = (body.location ?? {}) as Record<string, unknown>;
  const lat = num(loc.latitude ?? loc.lat);
  const lng = num(loc.longitude ?? loc.lng);
  const acc = num(loc.accuracyM ?? loc.accuracy_m ?? loc.accuracy);
  if (lat === null || lng === null || acc === null) {
    throw new StaffAttendanceValidationError(
      "LOCATION_REQUIRED",
      "location.latitude, longitude and accuracyM are required",
    );
  }
  const capturedAt = String(loc.capturedAt ?? loc.captured_at ?? "").trim();
  if (!capturedAt) {
    throw new StaffAttendanceValidationError(
      "LOCATION_REQUIRED",
      "location.capturedAt is required (a fresh fix per event)",
    );
  }

  const faceObj = (body.face ?? {}) as Record<string, unknown>;
  const embRaw = faceObj.embedding;
  if (!Array.isArray(embRaw) || embRaw.length === 0) {
    throw new StaffAttendanceValidationError(
      "FACE_REQUIRED",
      "face.embedding (live capture) is required — no device-biometric fallback",
    );
  }
  const embedding = embRaw.map((v) => {
    const n = num(v);
    if (n === null) {
      throw new StaffAttendanceValidationError("FACE_REQUIRED", "face.embedding must be numeric");
    }
    return n;
  });

  return {
    eventType: eventTypeRaw as StaffCheckEventType,
    location: {
      latitude: lat,
      longitude: lng,
      accuracyM: acc,
      isMock: loc.isMock === true || loc.is_mock === true || loc.mocked === true,
      capturedAt,
    },
    face: {
      embedding,
      livenessPassed: faceObj.livenessPassed === true || faceObj.liveness_passed === true,
      captureRef: faceObj.captureRef != null || faceObj.capture_ref != null
        ? String(faceObj.captureRef ?? faceObj.capture_ref)
        : null,
      modelTag: String(faceObj.modelTag ?? faceObj.model_tag ?? "").trim(),
    },
    staffName: String(body.staffName ?? body.staff_name ?? "").trim(),
    employeeRef: body.employeeRef != null || body.employee_ref != null
      ? String(body.employeeRef ?? body.employee_ref).trim()
      : null,
  };
}

export interface LocationVerdict {
  verified: boolean;
  distanceM: number;
}

/**
 * Enforce the §4 location hardening: anti-mock -> high-accuracy -> anti-stale ->
 * inside-geofence. Any failure throws with its specific code (no silent pass).
 * `nowMs` is injectable for deterministic tests.
 */
export function validateLocation(
  loc: AttendanceLocation,
  cfg: GeofenceConfig,
  nowMs: number,
): LocationVerdict {
  if (loc.isMock) {
    throw new StaffAttendanceValidationError(
      "MOCK_LOCATION",
      "Mock / spoofed location detected — attendance rejected",
    );
  }
  if (!(loc.accuracyM > 0) || loc.accuracyM > cfg.maxAccuracyM) {
    throw new StaffAttendanceValidationError(
      "LOW_ACCURACY",
      `Location accuracy ${loc.accuracyM}m exceeds the ${cfg.maxAccuracyM}m limit`,
    );
  }
  const capturedMs = Date.parse(loc.capturedAt);
  if (!Number.isFinite(capturedMs)) {
    throw new StaffAttendanceValidationError("STALE_LOCATION", "Invalid location timestamp");
  }
  const ageS = (nowMs - capturedMs) / 1000;
  if (ageS > cfg.maxLocationAgeS || ageS < -30) {
    throw new StaffAttendanceValidationError(
      "STALE_LOCATION",
      "Stale/cached location — a fresh fix is required for each event",
    );
  }
  const distanceM = haversineMeters(
    loc.latitude,
    loc.longitude,
    cfg.centerLatitude,
    cfg.centerLongitude,
  );
  if (distanceM > cfg.radiusM) {
    throw new StaffAttendanceValidationError(
      "OUTSIDE_GEOFENCE",
      `You are ${Math.round(distanceM)}m from school (geofence ${cfg.radiusM}m)`,
    );
  }
  return { verified: true, distanceM };
}

export interface FaceVerdict {
  matched: boolean;
  score: number;
}

/**
 * Server-authoritative face verification: liveness gate + CV match of the live
 * embedding against the enrolled reference (shared clamped cosine from
 * attendance_auth/face_match.ts; threshold env-tunable via
 * FACE_MATCH_MIN_SIMILARITY). Throws on liveness fail, model/dimension
 * mismatch (re-enrol, not a lookalike rejection), or no-match.
 */
export function verifyFace(
  face: AttendanceFace,
  reference: { embedding: number[]; modelTag?: string },
  threshold: number = faceMatchThreshold(),
): FaceVerdict {
  if (!face.livenessPassed) {
    throw new StaffAttendanceValidationError(
      "LIVENESS_FAILED",
      "Liveness check failed — hold your face to the live camera",
    );
  }
  const refModel = (reference.modelTag ?? "").trim();
  if (face.modelTag && refModel && face.modelTag !== refModel) {
    throw new StaffAttendanceValidationError(
      "FACE_EMBEDDING_MISMATCH",
      "Your capture used a different face model than your enrollment — re-enrol your face",
    );
  }
  if (
    face.embedding.length === 0 ||
    face.embedding.length !== reference.embedding.length
  ) {
    throw new StaffAttendanceValidationError(
      "FACE_EMBEDDING_MISMATCH",
      "Face embedding dimension mismatch — re-enrol your face",
    );
  }
  const score = cosineSimilarity(face.embedding, reference.embedding);
  // Fail-closed comparison: `!(score >= threshold)` also rejects NaN, where
  // `score < threshold` would fail OPEN (NaN compares false both ways).
  if (!(score >= threshold)) {
    throw new StaffAttendanceValidationError(
      "FACE_NO_MATCH",
      "Face did not match your enrolled reference",
    );
  }
  return { matched: true, score };
}
