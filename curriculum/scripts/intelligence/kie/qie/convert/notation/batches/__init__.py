"""Recovery BATCHES — the committed, re-runnable record of how certified knowledge was admitted.

`qie.db` is a derived local store (gitignored), so a batch file is the ONLY reproducible record of an
admission: which owned source page was read, what was transcribed from it, and which adversarial controls
guarded the batch. Losing them makes certified knowledge unreproducible — batch definitions are therefore
committed as compact governance JSON and replayed through the SAME `register.register` admission path.

A batch file is a JSON object:
    {"batch": "<id>", "extractor": "<lane/id>", "now": "<iso stamp>",
     "relations": [ <record>, ... ],          # proposed by the transcription model
     "controls":  [ <record>, ... ]}          # DELIBERATELY DAMAGED — must ALL be rejected

Control discipline is enforced mechanically, not by convention: `run()` certifies the controls FIRST and
refuses to admit anything if a damaged control certifies (that would mean a gate had regressed). Replaying a
batch is idempotent — `relation_id` is a hash of (subject, equation).
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Dict, List, Optional

from kie.qie.convert.notation import register as RG
from kie.qie.convert.notation import verify as V

BATCH_DIR = Path(__file__).parent


def available() -> List[str]:
    """Relation batches only. `chains.py` keeps its chain SETS in this same directory, and those carry a
    "chains" key with a different schema — listing them here made a bulk replay try to certify a mis-wired
    CHAIN as if it were a relation and die on the missing "equation"."""
    out = []
    for p in sorted(BATCH_DIR.glob("*.json")):
        try:
            if "relations" in json.loads(p.read_text()):
                out.append(p.stem)
        except Exception:
            continue
    return out


def load(name: str) -> dict:
    p = BATCH_DIR / f"{name}.json"
    if not p.exists():
        raise FileNotFoundError(f"no such batch {name!r}; available: {available()}")
    return json.loads(p.read_text())


class ControlBreach(RuntimeError):
    """A deliberately damaged control certified — a gate has regressed. Nothing may be admitted."""


def check_controls(batch: dict) -> List[dict]:
    """Certify every adversarial control. Raises ControlBreach if any of them passes."""
    out = []
    for rel in batch.get("controls") or []:
        v = V.certify(rel)
        out.append({"name": rel["name"], "status": v["status"], "failed_gates": v["failed_gates"]})
        if v["status"] != "rejected":
            raise ControlBreach(
                f"adversarial control {rel['name']!r} CERTIFIED — a gate has regressed; batch aborted")
    return out


def dry_run(name: str) -> dict:
    """Certify a batch without touching the store — the safe default."""
    batch = load(name)
    controls = check_controls(batch)
    verdicts = [{"name": r["name"], "equation": r["equation"], **V.certify(r)}
                for r in batch.get("relations") or []]
    return {"batch": batch.get("batch", name),
            "certified": sum(v["status"] == "certified" for v in verdicts),
            "rejected": sum(v["status"] != "certified" for v in verdicts),
            "controls_held": len(controls), "verdicts": verdicts, "controls": controls}


def run(name: str, qconn: sqlite3.Connection, now: Optional[str] = None) -> dict:
    """Replay a batch through the real admission path. Controls are verified first and are themselves
    persisted as rejects, so a damaged transcription is never re-processed."""
    batch = load(name)
    controls = check_controls(batch)                       # raises before anything is written
    stamp = now or batch.get("now") or "1970-01-01T00:00:00Z"
    extractor = batch.get("extractor", f"notation-recovery/{name}")
    admitted: List[dict] = []
    for rel in (batch.get("relations") or []) + (batch.get("controls") or []):
        v = RG.register(qconn, rel, stamp, extractor)
        admitted.append({"name": rel["name"], "status": v["status"], "relation_id": v["relation_id"]})
    return {"batch": batch.get("batch", name), "controls_held": len(controls),
            "certified": sum(a["status"] == "certified" for a in admitted),
            "rejected": sum(a["status"] != "certified" for a in admitted), "admitted": admitted}


def _main(argv: List[str]) -> int:
    import argparse
    from kie import config
    ap = argparse.ArgumentParser(prog="kie.qie.convert.notation.batches",
                                 description="Certify (and optionally admit) a recovery batch.")
    ap.add_argument("batch", nargs="?", help=f"batch id; one of {available()}")
    ap.add_argument("--register", action="store_true", help="admit into qie.db (default: dry run)")
    a = ap.parse_args(argv)
    if not a.batch:
        print("available batches:", ", ".join(available()))
        return 0
    if not a.register:
        r = dry_run(a.batch)
        for v in r["verdicts"]:
            mark = "CERT" if v["status"] == "certified" else "REJ "
            print(f"  {mark} {v['name']:42s} {v['equation']}")
            for g in v["failed_gates"]:
                print(f"        !! {g}: {v['gates'][g].get('reason')}")
        for c in r["controls"]:
            print(f"  CONTROL rejected (good): {c['name']}  [{', '.join(c['failed_gates'])}]")
        print(f"\n{r['batch']}: certified {r['certified']} / rejected {r['rejected']}, "
              f"{r['controls_held']} control(s) held  (dry run — pass --register to admit)")
        return 0
    conn = sqlite3.connect(str(config.KIE_HOME / "qie.db"))
    try:
        r = run(a.batch, conn)
    finally:
        conn.close()
    for x in r["admitted"]:
        print(f"  {x['status']:9s} {x['relation_id']}  {x['name']}")
    print(f"\n{r['batch']}: certified {r['certified']} / rejected {r['rejected']}, "
          f"{r['controls_held']} control(s) held")
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv[1:]))
