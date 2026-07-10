"""IntakeCenter — the orchestration facade for the Knowledge Intake Center.

Ties the pieces together into the mission pipeline, with NO resource bypassing it:

  collect → verify → dedup → version → [stage: parse → metadata → chunk → concept →
  graph → questions] → review queue → approval → (additive promotion + derived refresh)
  → production Knowledge Base.

The 360-doc certified baseline is immutable: only new / newer-version files are ever
staged, and only APPROVED items are promoted (additively). It orchestrates the existing
kie.phaseN components — it does not reimplement any of them.
"""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

from kie import config, store
from kie.intake import collector, detect, pipeline, promote
from kie.intake.models import (BatchStatus, Disposition, IntakeItemView,
                               ReviewStatus, SourceKind)
from kie.intake.store_ext import apply_intake_schema, now_iso


def _batch_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")


class IntakeCenter:
    def __init__(self, prod_db_path: Optional[Path] = None, intake_ws: Optional[Path] = None,
                 staging_dir: Optional[Path] = None):
        self.prod_db_path = str(prod_db_path) if prod_db_path else str(config.DB_PATH)
        self.intake_ws = Path(intake_ws) if intake_ws else config.WORKSPACE
        # Derive the parsed/reports/intake dirs from the DB's location so a custom --db
        # (CLI dry-runs, tests) is fully isolated; the parsed cache lives next to its store.
        dbp = Path(self.prod_db_path)
        if str(dbp) != ":memory:":
            config.KIE_HOME = dbp.parent
            config.PARSED_DIR = dbp.parent / "parsed"
            config.REPORTS_DIR = dbp.parent / "reports"
            config.INTAKE_HOME = dbp.parent / "intake"
            config.INTAKE_REPORTS_DIR = config.INTAKE_HOME / "reports"
            config.STAGING_DIR = config.INTAKE_HOME / "staging"
        self.staging_dir = Path(staging_dir) if staging_dir else config.STAGING_DIR
        config.ensure_dirs()
        config.ensure_intake_dirs()
        self.staging_dir.mkdir(parents=True, exist_ok=True)
        self._seq = 0

    def open(self):
        conn = store.open_store(self.prod_db_path)
        apply_intake_schema(conn)
        return conn

    # ── import (create a batch, verify+detect every file, stage the stageable ones) ──
    def import_paths(self, paths, source_kind: str = SourceKind.MULTIPLE,
                     category: Optional[str] = None, label: Optional[str] = None,
                     expand_zips: bool = True, batch_id: Optional[str] = None) -> dict:
        conn = self.open()
        try:
            return self._import(conn, paths, source_kind, category, label, expand_zips, batch_id)
        finally:
            conn.close()

    def _import(self, conn, paths, source_kind, category, label, expand_zips, batch_id) -> dict:
        self._seq += 1
        batch_id = batch_id or f"B_{_batch_stamp()}_{self._seq:03d}"
        sources = collector.collect_paths(paths, category=category, expand_zips=expand_zips)
        staging_path = self.staging_dir / f"{batch_id}.db"

        conn.execute(
            "INSERT OR REPLACE INTO intake_batches(batch_id, source_kind, label, status, staging_ref, created_at, updated_at)"
            " VALUES (?,?,?,?,?,?,?)",
            (batch_id, source_kind, label, BatchStatus.OPEN, str(staging_path), now_iso(), now_iso()))
        conn.commit()

        staging = store.open_store(str(staging_path))
        staged_docs: List[tuple] = []   # (item_id, doc_id, detection)
        summary = {"batch_id": batch_id, "total": 0, "staged": 0, "duplicates": 0,
                   "quarantined": 0, "new_versions": 0}
        try:
            for i, src in enumerate(sources, start=1):
                summary["total"] += 1
                item_id = f"{batch_id}#{i}"
                verdict = detect.verify_file(Path(src.origin_path))
                det = detect.classify_source(conn, verdict, src.category, src.original_name, src.lineage_key)
                disp = det["disposition"]

                review_status = ReviewStatus.SKIPPED
                flags: List[str] = []
                stats = {}
                rel = None

                if disp in Disposition.STAGEABLE:
                    rel = pipeline.stage_resource(Path(src.origin_path), det["doc_id"], src.original_name, self.intake_ws)
                    pipeline.ingest_to_staging(staging, verdict, rel, src.category)
                    staged_docs.append((item_id, det["doc_id"], det))
                    if disp == Disposition.NEW_VERSION:
                        summary["new_versions"] += 1
                elif disp == Disposition.EXACT_DUPLICATE:
                    summary["duplicates"] += 1
                    flags = [f"exact_duplicate_of:{det.get('existing_doc_id')}"]
                elif disp == Disposition.QUARANTINED:
                    summary["quarantined"] += 1
                    flags = [f"quarantined:{det.get('certify_reason')}"]

                self._insert_item(conn, item_id, batch_id, src, verdict, det, rel,
                                  review_status, flags, stats)

            # run the deterministic pipeline over the staged docs (isolated in staging)
            if staged_docs:
                pipeline.run_phases(staging, self.intake_ws)
                for item_id, doc_id, det in staged_docs:
                    flags = pipeline.staged_flags(staging, doc_id)
                    stats = pipeline.staged_stats(staging, doc_id).to_dict()
                    rstatus = pipeline.review_status_for(flags)
                    self._update_item_after_stage(conn, item_id, rstatus, flags, stats)
                    summary["staged"] += 1
        finally:
            staging.close()

        conn.execute("UPDATE intake_batches SET status=?, updated_at=? WHERE batch_id=?",
                     (BatchStatus.STAGED, now_iso(), batch_id))
        conn.commit()
        summary["pending_review"] = conn.execute(
            "SELECT COUNT(*) n FROM intake_items WHERE batch_id=? AND review_status IN (?,?)",
            (batch_id, ReviewStatus.PENDING, ReviewStatus.NEEDS_REVIEW)).fetchone()["n"]
        return summary

    def _insert_item(self, conn, item_id, batch_id, src, verdict, det, rel, review_status, flags, stats):
        import json
        conn.execute(
            "INSERT OR REPLACE INTO intake_items(item_id, batch_id, doc_id, sha256, original_name, source_path,"
            " corpus, rel_path, category, lineage_key, verify_status, certify_status, disposition, version_of,"
            " version_no, review_status, flags, stats, created_at, updated_at)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (item_id, batch_id, det["doc_id"], verdict["sha256"], src.original_name, src.origin_path,
             "intake", rel, src.category, det["lineage_key"], det["verify_status"], det["certify_status"],
             det["disposition"], det.get("version_of"), det.get("version_no"), review_status,
             json.dumps(flags), json.dumps(stats), now_iso(), now_iso()))
        conn.commit()

    def _update_item_after_stage(self, conn, item_id, review_status, flags, stats):
        import json
        conn.execute(
            "UPDATE intake_items SET review_status=?, flags=?, stats=?, updated_at=? WHERE item_id=?",
            (review_status, json.dumps(flags), json.dumps(stats), now_iso(), item_id))
        conn.commit()

    # ── review queue ────────────────────────────────────────────────────────────────
    def list_queue(self, status: Optional[str] = None, batch_id: Optional[str] = None) -> List[IntakeItemView]:
        conn = self.open()
        try:
            sql = "SELECT * FROM intake_items"
            where, args = [], []
            if status:
                where.append("review_status=?"); args.append(status)
            if batch_id:
                where.append("batch_id=?"); args.append(batch_id)
            if where:
                sql += " WHERE " + " AND ".join(where)
            sql += " ORDER BY item_id"
            return [self._view(r) for r in conn.execute(sql, args).fetchall()]
        finally:
            conn.close()

    def get_item(self, item_id: str) -> Optional[IntakeItemView]:
        conn = self.open()
        try:
            r = conn.execute("SELECT * FROM intake_items WHERE item_id=?", (item_id,)).fetchone()
            return self._view(r) if r else None
        finally:
            conn.close()

    def preview_concepts(self, item_id: str, limit: int = 12) -> List[str]:
        """A sample of concept titles a staged item introduced (read from its staging DB)."""
        conn = self.open()
        try:
            r = conn.execute("SELECT batch_id, doc_id FROM intake_items WHERE item_id=?", (item_id,)).fetchone()
            if not r or not r["doc_id"]:
                return []
            staging_path = self._staging_ref(conn, r["batch_id"])
        finally:
            conn.close()
        if not staging_path or not Path(staging_path).exists():
            return []
        s = store.open_store(str(staging_path))
        try:
            return pipeline.sample_concepts(s, r["doc_id"], limit)
        finally:
            s.close()

    # ── decisions ────────────────────────────────────────────────────────────────────
    def approve(self, item_id: str, reviewer: Optional[str] = None, notes: Optional[str] = None,
                refresh: bool = True) -> dict:
        conn = self.open()
        try:
            row = self._require_open(conn, item_id)
            det = self._detection_of(row)
            staging_path = self._staging_ref(conn, row["batch_id"])
            if row["promoted_at"] is None:
                promote.promote_document(conn, Path(staging_path), row["doc_id"], det, item_id=item_id)
            conn.execute(
                "UPDATE intake_items SET review_status=?, reviewer=?, notes=?, decided_at=?, promoted_at=?, updated_at=?"
                " WHERE item_id=?",
                (ReviewStatus.APPROVED, reviewer, notes, now_iso(), now_iso(), now_iso(), item_id))
            conn.commit()
            self._maybe_close_batch(conn, row["batch_id"])
            out = {"item_id": item_id, "review_status": ReviewStatus.APPROVED, "doc_id": row["doc_id"],
                   "promoted": True, "disposition": row["disposition"]}
            if refresh:
                out["derived"] = promote.refresh_derived(conn)
                conn.commit()
            return out
        finally:
            conn.close()

    def reject(self, item_id: str, reviewer: Optional[str] = None, notes: Optional[str] = None) -> dict:
        conn = self.open()
        try:
            row = self._require_open(conn, item_id)
            conn.execute(
                "UPDATE intake_items SET review_status=?, reviewer=?, notes=?, decided_at=?, updated_at=? WHERE item_id=?",
                (ReviewStatus.REJECTED, reviewer, notes, now_iso(), now_iso(), item_id))
            conn.commit()
            self._maybe_close_batch(conn, row["batch_id"])
            return {"item_id": item_id, "review_status": ReviewStatus.REJECTED}
        finally:
            conn.close()

    def flag_for_review(self, item_id: str, reviewer: Optional[str] = None, notes: Optional[str] = None) -> dict:
        conn = self.open()
        try:
            conn.execute(
                "UPDATE intake_items SET review_status=?, reviewer=?, notes=?, updated_at=? WHERE item_id=?",
                (ReviewStatus.NEEDS_REVIEW, reviewer, notes, now_iso(), item_id))
            conn.commit()
            return {"item_id": item_id, "review_status": ReviewStatus.NEEDS_REVIEW}
        finally:
            conn.close()

    def refresh_production(self) -> dict:
        """Run the Knowledge Graph Update + Question Intelligence Update globally (idempotent)."""
        conn = self.open()
        try:
            out = promote.refresh_derived(conn)
            conn.commit()
            return out
        finally:
            conn.close()

    # ── local watch folder (one poll pass; a loop wraps this in the CLI) ──────────────
    def poll_watch_folder(self, folder: Path, category: Optional[str] = None) -> dict:
        conn = self.open()
        try:
            known = {r["rel_path"]: r["sha256"]
                     for r in conn.execute("SELECT rel_path, sha256 FROM watch_state WHERE folder=?",
                                           (str(folder),)).fetchall()}
        finally:
            conn.close()
        sources, current = collector.scan_watch_folder(known, Path(folder), category)
        result = {"folder": str(folder), "new_or_changed": len(sources), "batch_id": None}
        if sources:
            summary = self.import_paths([s.origin_path for s in sources], source_kind=SourceKind.WATCH,
                                        category=category)
            result["batch_id"] = summary["batch_id"]
            result["summary"] = summary
        # persist the new watch index (control table only)
        conn = self.open()
        try:
            for rel, sha in current.items():
                conn.execute(
                    "INSERT OR REPLACE INTO watch_state(folder, rel_path, sha256, seen_at) VALUES (?,?,?,?)",
                    (str(folder), rel, sha, now_iso()))
            conn.commit()
        finally:
            conn.close()
        return result

    def register_baseline_lineage(self) -> int:
        conn = self.open()
        try:
            return detect.register_baseline_lineage(conn)
        finally:
            conn.close()

    # ── helpers ──────────────────────────────────────────────────────────────────────
    def _require_open(self, conn, item_id):
        row = conn.execute("SELECT * FROM intake_items WHERE item_id=?", (item_id,)).fetchone()
        if not row:
            raise KeyError(f"unknown intake item: {item_id}")
        if row["disposition"] not in Disposition.STAGEABLE:
            raise ValueError(f"item {item_id} is {row['disposition']} — not reviewable/promotable")
        if row["review_status"] not in ReviewStatus.OPEN and row["promoted_at"] is None:
            raise ValueError(f"item {item_id} already {row['review_status']}")
        return row

    def _detection_of(self, row) -> dict:
        return {
            "doc_id": row["doc_id"],
            "disposition": row["disposition"],
            "lineage_key": row["lineage_key"],
            "version_no": row["version_no"],
            "version_of": row["version_of"],
            "year": detect.year_from(row["original_name"]),
        }

    def _staging_ref(self, conn, batch_id) -> Optional[str]:
        r = conn.execute("SELECT staging_ref FROM intake_batches WHERE batch_id=?", (batch_id,)).fetchone()
        return r["staging_ref"] if r else None

    def _maybe_close_batch(self, conn, batch_id):
        open_n = conn.execute(
            "SELECT COUNT(*) n FROM intake_items WHERE batch_id=? AND review_status IN (?,?)",
            (batch_id, ReviewStatus.PENDING, ReviewStatus.NEEDS_REVIEW)).fetchone()["n"]
        if open_n == 0:
            conn.execute("UPDATE intake_batches SET status=?, updated_at=? WHERE batch_id=?",
                         (BatchStatus.CLOSED, now_iso(), batch_id))
            conn.commit()

    def _view(self, r) -> IntakeItemView:
        import json
        return IntakeItemView(
            item_id=r["item_id"], batch_id=r["batch_id"], doc_id=r["doc_id"],
            original_name=r["original_name"], category=r["category"], disposition=r["disposition"],
            version_of=r["version_of"], version_no=r["version_no"], review_status=r["review_status"],
            verify_status=r["verify_status"], certify_status=r["certify_status"],
            flags=json.loads(r["flags"] or "[]"), stats=json.loads(r["stats"] or "{}"),
            lineage_key=r["lineage_key"], notes=r["notes"])
