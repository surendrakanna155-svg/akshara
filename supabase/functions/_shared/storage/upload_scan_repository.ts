// PRC-A Batch 9 — Upload scan-result ledger repository + serving gate.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, type TenantQueryClient, withTenantContext } from "../tenant_db.ts";
import {
  malwareScanEnforcementEnabled,
  resolveScanDisposition,
  type ScanStatus,
} from "./upload_scan_service.ts";

export interface UploadScanRow {
  id: string;
  organization_id: string;
  school_id: string;
  bucket: string;
  object_key: string;
  module: string;
  status: string;
  engine: string;
  detail: string | null;
  scanned_at: string | null;
  requested_by: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Record a scan result for a freshly-confirmed upload. Idempotent on
 * (organization_id, object_key) — a re-confirm of the same object never
 * duplicates or downgrades an existing verdict.
 */
export async function recordUploadScan(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    bucket: string;
    objectKey: string;
    module: string;
    status: ScanStatus;
    engine: string;
    requestedBy: string;
  },
): Promise<void> {
  await db.queryObject(
    `INSERT INTO upload_scan_results (
       organization_id, school_id, bucket, object_key, module, status, engine,
       scanned_at, requested_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7,
       CASE WHEN $6 IN ('clean','infected','skipped') THEN timezone('utc', now()) ELSE NULL END,
       $8)
     ON CONFLICT (organization_id, object_key) DO NOTHING`,
    [
      input.organizationId,
      input.schoolId,
      input.bucket,
      input.objectKey,
      input.module,
      input.status,
      input.engine,
      input.requestedBy,
    ],
  );
}

export async function getUploadScan(
  db: TenantQueryClient,
  orgId: string,
  objectKey: string,
): Promise<UploadScanRow | null> {
  const rows = await db.queryObject<UploadScanRow>(
    `SELECT * FROM upload_scan_results
      WHERE organization_id = $1 AND object_key = $2`,
    [orgId, objectKey],
  );
  return rows[0] ?? null;
}

/** Record an AV verdict against a previously-recorded object (pending → clean/
 * infected). The status guard makes a stale/duplicate callback a no-op. */
export async function setScanVerdict(
  db: TenantQueryClient,
  orgId: string,
  objectKey: string,
  status: ScanStatus,
  detail: string | null,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE upload_scan_results
        SET status = $3, detail = $4, scanned_at = timezone('utc', now()),
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND object_key = $2 AND status = 'pending'
      RETURNING id`,
    [orgId, objectKey, status, detail],
  );
  return rows.length > 0;
}

/**
 * Serving gate for an object download/share. Returns a blocking Response when the
 * object's scan verdict forbids serving, or null when it may be served. Behind
 * MALWARE_SCAN_ENFORCEMENT (default off → always null → no behaviour change).
 * Fails OPEN on any error — a scan-lookup failure must never take downloads
 * offline. Never throws.
 */
export async function enforceUploadScanGate(
  config: AppConfig,
  claims: AccessTokenClaims,
  objectKey: string,
): Promise<Response | null> {
  if (!malwareScanEnforcementEnabled()) return null;
  try {
    const disposition = await withTenantContext(config, claims, async (db) => {
      const row = await getUploadScan(db, claims.tenant_id, objectKey);
      return resolveScanDisposition((row?.status as ScanStatus) ?? null, true);
    });
    if (disposition === "block") {
      return errorEnvelope("UPLOAD_BLOCKED", "This file was flagged by malware scanning.", 403);
    }
    if (disposition === "hold") {
      return errorEnvelope("SCAN_PENDING", "This file is still being scanned. Try again shortly.", 409);
    }
    return null;
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return null;
    console.error("upload scan gate failed (fail-open):", error);
    return null;
  }
}
