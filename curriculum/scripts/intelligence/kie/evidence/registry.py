"""Canonical evidence registry scanner — deterministic, re-runnable, read-only.

Probes live metrics for every declared Store (size, doc/file counts, DB table snapshots, knowledge-state
rollups) and emits the single canonical inventory (JSON + Markdown). READ-ONLY on all evidence: it never
moves, renames, or deletes anything. Re-run it to refresh the inventory as evidence advances through the
lifecycle. The compact JSON/MD are git-tracked; the raw evidence they describe stays local (gitignored).
"""
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
from dataclasses import asdict
from pathlib import Path
from typing import Dict, List, Optional

from kie import config
from kie.evidence import lifecycle as L

WORKSPACE = config.WORKSPACE
OUT_JSON = WORKSPACE / "EVIDENCE_REGISTRY.json"
OUT_MD = WORKSPACE / "EVIDENCE_REGISTRY.md"


def _du_bytes(path: Path) -> int:
    """Fast store size via `du -sk` (KB). Returns 0 if the path is absent."""
    if not path.exists():
        return 0
    try:
        out = subprocess.run(["du", "-sk", str(path)], capture_output=True, text=True, timeout=180)
        return int(out.stdout.split("\t")[0]) * 1024
    except Exception:
        return 0


def _count_files(path: Path, exts=(".pdf",)) -> int:
    if not path.exists():
        return 0
    n = 0
    for _root, _dirs, files in os.walk(path):
        for f in files:
            if f.lower().endswith(exts):
                n += 1
    return n


def _manifest_counts(rel: str) -> Optional[dict]:
    p = WORKSPACE / rel
    if not p.exists():
        return None
    try:
        d = json.loads(p.read_text())
        return d.get("counts", d) if isinstance(d, dict) else None
    except Exception:
        return None


def _table_counts(dbpath: Path, tables: List[str]) -> Dict[str, int]:
    out: Dict[str, int] = {}
    if not dbpath.exists():
        return out
    try:
        c = sqlite3.connect(f"file:{dbpath}?mode=ro", uri=True)
        for t in tables:
            try:
                out[t] = c.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
            except Exception:
                pass
        c.close()
    except Exception:
        pass
    return out


def _qie_knowledge_state(dbpath: Path) -> dict:
    """The decision-critical rollup: how much VERIFIED, USABLE knowledge exists (vs raw table rows)."""
    st: dict = {}
    if not dbpath.exists():
        return st
    c = sqlite3.connect(f"file:{dbpath}?mode=ro", uri=True)

    def q(sql):
        try:
            return c.execute(sql).fetchone()[0]
        except Exception:
            return None
    st["kvs_assertion_total"] = q("SELECT COUNT(*) FROM kvs_assertion")
    st["kvs_assertion_corroborated_ge2"] = q(
        "SELECT COUNT(*) FROM kvs_assertion WHERE evidence_count>=2 AND assertion_id LIKE 'KV1_%'")
    st["kvs_structure_function"] = q("SELECT COUNT(*) FROM kvs_structure_function")
    st["kvs_sequence"] = q("SELECT COUNT(*) FROM kvs_sequence")
    st["kvs_comparison"] = q("SELECT COUNT(*) FROM kvs_comparison")
    st["kvs_taxonomy"] = q("SELECT COUNT(*) FROM kvs_taxonomy")
    st["tier2_agree"] = q("SELECT COUNT(*) FROM tier2_verdict WHERE verdict='agree'")
    st["distractor_dna"] = q("SELECT COUNT(*) FROM distractor_dna")
    st["item_model"] = q("SELECT COUNT(*) FROM item_model")
    st["item_model_ai_validated"] = q("SELECT COUNT(*) FROM item_model WHERE certification_status='ai_validated'")
    st["pilot_verified_item"] = q("SELECT COUNT(*) FROM pilot_verified_item")
    st["governed_fact_verified"] = q("SELECT COUNT(*) FROM governed_fact WHERE status='verified'")
    # notation lane (owner decision A): relations recovered from owned source images + deterministically certified
    st["governed_relation_certified"] = q("SELECT COUNT(*) FROM governed_relation WHERE status='certified'")
    st["governed_relation_rejected"] = q("SELECT COUNT(*) FROM governed_relation WHERE status='rejected'")
    c.close()
    return st


def _kie_knowledge_state(dbpath: Path) -> dict:
    st: dict = {}
    counts = _table_counts(dbpath, ["chunks", "concepts", "question_patterns", "formulas", "documents"])
    st.update(counts)
    if dbpath.exists():
        c = sqlite3.connect(f"file:{dbpath}?mode=ro", uri=True)
        try:
            st["formulas_with_symbols"] = c.execute(
                "SELECT COUNT(*) FROM formulas WHERE symbols IS NOT NULL AND symbols<>''").fetchone()[0]
        except Exception:
            pass
        c.close()
    return st


def scan_store(s: L.Store) -> dict:
    path = WORKSPACE / s.physical_path
    rec = asdict(s)
    rec["role"] = s.role.value
    rec["state"] = s.state.value
    rec["scope"] = s.scope.value
    rec["git"] = s.git.value
    rec["exists"] = path.exists()
    rec["size_bytes"] = _du_bytes(path)
    rec["size_human"] = _human(rec["size_bytes"])
    # attach live detail metrics per store
    live: dict = {}
    if s.canonical_id == "STG_QCORPUS":
        live = _manifest_counts("staging/qcorpus_noncert/manifests/_manifest_counts.json") or {}
    elif s.canonical_id == "KDB_QIE":
        live = _qie_knowledge_state(path)
    elif s.canonical_id == "KDB_KIE":
        live = _kie_knowledge_state(path)
    elif s.role == L.Role.RAW or s.role == L.Role.QUARANTINE:
        live = {"pdf_files": _count_files(path, (".pdf",))}
    rec["live"] = live
    return rec


def _human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return f"{n:.1f} TB"


def build(now: str) -> dict:
    stores = [scan_store(s) for s in L.STORES]
    by_scope: Dict[str, int] = {}
    by_state: Dict[str, int] = {}
    total_bytes = 0
    for r in stores:
        by_scope[r["scope"]] = by_scope.get(r["scope"], 0) + 1
        by_state[r["state"]] = by_state.get(r["state"], 0) + 1
        total_bytes += r["size_bytes"]
    return {
        "_registry": "Akshara Canonical Evidence & Knowledge Governance Registry",
        "_authority": "Single store-level source of truth for owned QIE/curriculum evidence + lifecycle state.",
        "_owner_correction": "2026-07-14 evidence-storage governance reconciliation",
        "generated_at": now,
        "workspace": str(WORKSPACE),
        "lifecycle_states": [s.value for s in L.State],
        "totals": {"stores": len(stores), "total_bytes": total_bytes, "total_human": _human(total_bytes),
                   "by_scope": by_scope, "by_state": by_state},
        "stores": stores,
    }


def write(now: str) -> dict:
    reg = build(now)
    OUT_JSON.write_text(json.dumps(reg, indent=2))
    OUT_MD.write_text(render_md(reg))
    return reg


def render_md(reg: dict) -> str:
    t = reg["totals"]
    lines = [
        "# Akshara — Canonical Evidence & Knowledge Governance Registry",
        "",
        f"**Generated:** {reg['generated_at']} · **Authority:** single store-level source of truth for ALL "
        "owned QIE/curriculum evidence + its lifecycle state. Re-run "
        "`python -m kie.evidence.registry` to refresh.",
        "",
        f"**Totals:** {t['stores']} stores · {t['total_human']} · "
        f"by scope {t['by_scope']} · by state {t['by_state']}",
        "",
        "Lifecycle: `1_raw → 2_ocr → 3_extracted → 4_recovered → 5_verified → 6_concept_bound → "
        "7_qie_available` (`q_quarantine` = rejected/out-of-scope/superseded).",
        "",
        "| id | path | role | state | scope | size | detail |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in reg["stores"]:
        detail = ""
        lv = r.get("live") or {}
        if r["canonical_id"] == "STG_QCORPUS":
            detail = f"{lv.get('extracted_questions','?')} Q / {lv.get('corpus_inventory','?')} docs"
        elif r["canonical_id"] == "KDB_QIE":
            detail = (f"facts:{lv.get('governed_fact_verified')} SF:{lv.get('kvs_structure_function')} "
                      f"seq:{lv.get('kvs_sequence')} cmp:{lv.get('kvs_comparison')} "
                      f"distr:{lv.get('distractor_dna')} · relations:{lv.get('governed_relation_certified')} "
                      f"cert/{lv.get('governed_relation_rejected')} rej · bank:{lv.get('pilot_verified_item')}")
        elif r["canonical_id"] == "KDB_KIE":
            detail = (f"chunks:{lv.get('chunks')} concepts:{lv.get('concepts')} "
                      f"formulas:{lv.get('formulas')} (w/symbols:{lv.get('formulas_with_symbols')})")
        elif "pdf_files" in lv:
            detail = f"{lv['pdf_files']} PDFs"
        exists = "" if r["exists"] else " ⚠️MISSING"
        lines.append(f"| {r['canonical_id']} | `{r['physical_path']}`{exists} | {r['role']} | "
                     f"{r['state']} | {r['scope']} | {r['size_human']} | {detail} |")
    lines += [
        "",
        "## How to read a lifecycle state",
        "- **1_raw / 2_ocr / 3_extracted** — evidence exists but is NOT usable knowledge. An extracted "
        "question is not a QIE-available record.",
        "- **5_verified** — structured facts/relations, independently verified (deterministic + examiner).",
        "- **6_concept_bound / 7_qie_available** — safely bound to a certified concept and reachable by the "
        "unified engine → qpgen.",
        "",
        "## Detail layers (this registry references, never duplicates)",
        "- Per-file curriculum provenance → `PROVENANCE_MANIFEST.json`, `indexes/`, `reports/`.",
        "- Per-doc qcorpus extraction → `staging/qcorpus_noncert/manifests/*.jsonl`.",
        "- Verified knowledge rows → `knowledge/kie/qie.db` (KVS + item_model + pilot_verified_item).",
        "",
        "See `EVIDENCE_MIGRATION_MAP.md` for the deferred old-path → canonical-path physical layout.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    import datetime  # noqa
    # deterministic timestamp comes from the caller in tests; CLI stamps now.
    now = os.environ.get("REGISTRY_NOW") or subprocess.run(
        ["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], capture_output=True, text=True).stdout.strip()
    reg = write(now)
    t = reg["totals"]
    print(f"evidence registry written: {t['stores']} stores, {t['total_human']}")
    print(f"  {OUT_JSON}")
    print(f"  {OUT_MD}")


if __name__ == "__main__":
    main()
