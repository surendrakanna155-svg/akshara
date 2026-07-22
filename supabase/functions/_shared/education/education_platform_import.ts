// Program D · M1.3 — ERP platform importer (service-role, idempotent, fail-closed).
//
// Ingests the frozen Contract-1 export artifact ({manifest, rows}) into
// edu_platform_question_bank. This is the ONLINE end of the offline→online boundary
// (docs/roadmap/PROGRAM_D_CONTRACTS.md). It is DORMANT until wired behind an
// owner-gated invoke path; nothing calls it on the request path.
//
// INVARIANTS (fail-closed):
//   * Manifest fingerprint mismatch (recomputed content_fp ≠ manifest.content_fp, or
//     row_count ≠ rows.length) → REFUSE the whole import (PlatformImportRefused).
//   * A malformed/duplicate row → REFUSE before ANY write (validate-all-first; no
//     partial write).
//   * Idempotent by content_hash: re-importing the same artifact inserts nothing and
//     tombstones nothing (existing rows are re-asserted to identical content).
//   * Recall = TOMBSTONE, never hard-delete: the artifact is the authoritative FULL
//     certified set (the exporter always reads the whole certified_bank), so an active
//     platform row whose content_hash is absent from the artifact is tombstoned
//     (status='tombstoned', recalled_at set) — which drops it from every adopting
//     school's union automatically.
//
// Platform rows carry organization_id NULL and are writable ONLY by the platform
// service role (RLS bypass) — this module must run on a service-role connection, never
// the tenant (erp_tenant) client.

/** Minimal DB surface so a service-role client OR a test FakeDb can drive the import. */
export interface PlatformImportDb {
  queryObject<T>(sql: string, args: unknown[]): Promise<T[]>;
}

export interface ExportManifest {
  artifact_version: string;
  generated_from: string;
  content_fp: string;
  substrate_fp: string;
  row_count: number;
  near_dup_model_version: string;
  near_dup_threshold_version: string;
  enum_map_version: string;
  frozen_version: string;
}

export interface ExportRow {
  content_hash: string;
  stem_norm_hash: string;
  question_text: string;
  answer_text: string;
  options: string[];
  answer_label: string;
  question_type: string;
  difficulty: string;
  difficulty_calibration: string;
  cognitive_level: string | null;
  marks: number;
  subject_name: string;
  chapter: string;
  topic: string;
  program_track: string;
  kc_id: string;
  concept_uuid: string;
  near_dup_embedding: number[];
  provenance: Record<string, unknown>;
  frozen_version: string;
}

export interface ExportArtifact {
  manifest: ExportManifest;
  rows: ExportRow[];
}

export interface PlatformImportResult {
  inserted: number;
  updated: number;
  tombstoned: number;
  skipped: number;
  rowCount: number;
}

/** A fail-closed refusal — the artifact is untrusted until its fingerprint checks out. */
export class PlatformImportRefused extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PlatformImportRefused";
  }
}

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Recompute the D4 freeze fingerprint EXACTLY as the exporter does (manifest.py::content_fp):
 * sha256 over the row content_hashes, sorted ascending then newline-joined. */
export async function recomputeContentFp(rows: ExportRow[]): Promise<string> {
  return await sha256Hex(rows.map((r) => r.content_hash).sort().join("\n"));
}

function refuseIf(cond: boolean, message: string): void {
  if (cond) throw new PlatformImportRefused(message);
}

function validateRow(row: ExportRow, i: number): void {
  const bad = (m: string) => new PlatformImportRefused(`malformed export row ${i}: ${m}`);
  if (typeof row?.content_hash !== "string" || row.content_hash.length === 0) throw bad("missing content_hash");
  if (typeof row.question_text !== "string" || row.question_text.length === 0) throw bad("missing question_text");
  if (typeof row.subject_name !== "string" || row.subject_name.length === 0) throw bad("missing subject_name");
  if (typeof row.question_type !== "string" || row.question_type.length === 0) throw bad("missing question_type");
  if (typeof row.marks !== "number" || !(row.marks > 0)) throw bad("marks must be a positive number");
  if (!Array.isArray(row.options)) throw bad("options must be an array");
  if (typeof row.concept_uuid !== "string" || row.concept_uuid.length === 0) {
    throw bad("missing concept_uuid (exporter must only ship mapped rows)");
  }
  if (typeof row.difficulty_calibration !== "string") throw bad("missing difficulty_calibration");
}

const INSERT_SQL = `INSERT INTO edu_platform_question_bank
  (organization_id, school_id, content_hash, stem_norm_hash, subject_name, chapter, topic,
   difficulty, difficulty_calibration, question_type, marks, question_text, answer_text,
   options, answer_label, cognitive_level, program_track, kc_id, concept_uuid,
   near_dup_embedding, near_dup_model_version, provenance, frozen_version, status)
  VALUES (NULL, NULL, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
          $12::jsonb, $13, $14, $15, $16, $17, $18::jsonb, $19, $20::jsonb, $21, 'active')`;

// Refresh an EXISTING platform row (re-export): reassert content + REACTIVATE (a recalled
// item that is re-certified and re-exported comes back active). content_hash is $1.
const UPDATE_SQL = `UPDATE edu_platform_question_bank SET
  stem_norm_hash = $2, subject_name = $3, chapter = $4, topic = $5, difficulty = $6,
  difficulty_calibration = $7, question_type = $8, marks = $9, question_text = $10,
  answer_text = $11, options = $12::jsonb, answer_label = $13, cognitive_level = $14,
  program_track = $15, kc_id = $16, concept_uuid = $17, near_dup_embedding = $18::jsonb,
  near_dup_model_version = $19, provenance = $20::jsonb, frozen_version = $21,
  status = 'active', recalled_at = NULL, updated_at = timezone('utc', now())
  WHERE content_hash = $1`;

const TOMBSTONE_SQL = `UPDATE edu_platform_question_bank SET
  status = 'tombstoned', recalled_at = timezone('utc', now()), updated_at = timezone('utc', now())
  WHERE content_hash = $1 AND status = 'active'`;

function rowArgs(row: ExportRow, modelVersion: string): unknown[] {
  return [
    row.content_hash, row.stem_norm_hash, row.subject_name, row.chapter, row.topic,
    row.difficulty, row.difficulty_calibration, row.question_type, row.marks, row.question_text,
    row.answer_text, JSON.stringify(row.options), row.answer_label, row.cognitive_level,
    row.program_track, row.kc_id, row.concept_uuid, JSON.stringify(row.near_dup_embedding),
    modelVersion, JSON.stringify(row.provenance), row.frozen_version,
  ];
}

/**
 * Import the export artifact into edu_platform_question_bank. Runs on a service-role
 * connection (platform rows have org NULL and are RLS-bypass-write only). Returns the
 * per-outcome counts. Throws PlatformImportRefused on any fail-closed condition BEFORE
 * writing anything.
 */
export async function importPlatformBatch(
  db: PlatformImportDb,
  artifact: ExportArtifact,
): Promise<PlatformImportResult> {
  const { manifest, rows } = artifact;

  // 1. Manifest verification — fail-closed, before any DB access.
  refuseIf(!manifest || typeof manifest.content_fp !== "string", "artifact has no manifest.content_fp");
  refuseIf(!Array.isArray(rows), "artifact rows is not an array");
  refuseIf(rows.length !== manifest.row_count,
    `manifest row_count ${manifest.row_count} != rows.length ${rows.length}`);
  const fp = await recomputeContentFp(rows);
  refuseIf(fp !== manifest.content_fp,
    `manifest content_fp mismatch (recomputed ${fp} != ${manifest.content_fp}) — refusing import`);

  // 2. Validate ALL rows + reject duplicate content_hash before ANY write (no partial write).
  const seen = new Set<string>();
  rows.forEach((row, i) => {
    validateRow(row, i);
    refuseIf(seen.has(row.content_hash), `duplicate content_hash ${row.content_hash} in artifact`);
    seen.add(row.content_hash);
  });

  // 3. Read current platform state (service-role SELECT).
  const existing = await db.queryObject<{ content_hash: string; status: string }>(
    "SELECT content_hash, status FROM edu_platform_question_bank", []);
  const existingStatus = new Map(existing.map((r) => [r.content_hash, r.status]));
  const artifactHashes = new Set(rows.map((r) => r.content_hash));

  let inserted = 0, updated = 0, tombstoned = 0;

  // 4. Upsert by content_hash (idempotent — identical content re-asserted on update).
  for (const row of rows) {
    const args = rowArgs(row, manifest.near_dup_model_version);
    if (existingStatus.has(row.content_hash)) {
      await db.queryObject(UPDATE_SQL, args);
      updated++;
    } else {
      await db.queryObject(INSERT_SQL, args);
      inserted++;
    }
  }

  // 5. Recall propagation: tombstone active rows absent from the full-sync artifact.
  for (const [hash, status] of existingStatus) {
    if (status === "active" && !artifactHashes.has(hash)) {
      await db.queryObject(TOMBSTONE_SQL, [hash]);
      tombstoned++;
    }
  }

  return { inserted, updated, tombstoned, skipped: 0, rowCount: rows.length };
}
