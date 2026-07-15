"""Governed TOPIC layer — owner decision B (2026-07-15). The qualitative lane's concept granularity.

WHY. qpgen dedups by `(concept_code, question_type)` and `used_ct` is GLOBAL across a paper, so binding a
governed fact to its CHAPTER meant **one chapter = ONE question in the whole paper**. Measured, that capped
NEET Biology at 42% forever (938 clean candidates but only 38 chapters) and Chemistry at 64% — no amount of
examining could pass it. Relations never had this problem because they bind at relation granularity
("Physics :: Ohm's law"), worth +8 vs +1. This gives the qualitative lane the same fix.

WHAT A TOPIC IS. The smallest GENUINE curriculum concept the verified fact teaches — "Uricotelism" inside the
chapter "Excretory Products And Their Elimination". It is **authored short** (the owner's constraint), exactly
as a relation's `name` is authored short. It is NOT a truncation of `subject_term` or source prose:
`_clean_title` caps at 5 words, so truncating prose yields fragments ("Hydrolysis of nitrile (from alkyl")
that are unfit to print as a concept title.

GOVERNANCE — the LLM proposes a topic; DETERMINISTIC gates certify it (the same split as every other lane):
  * SUBJECT      — the fact's subject hard-gate is inherited untouched; a topic never re-opens it.
  * SANITIZER    — must pass the SAME `qpgen.sanitize.is_clean_concept` every other in-scope concept passes
                   (MAX_WORDS=5), via `qp_bridge._clean_title`.
  * GROUNDING    — every significant word of the topic must occur in the fact's OWN verified evidence
                   (fact_text / answer / structured slots / stem excerpt / chapter). This is the mechanical
                   guard against the owner's explicit prohibition: inventing an artificial topic name merely
                   to buy a qpgen dedup slot. A topic that cannot be grounded in the evidence is REFUSED —
                   the fact then keeps its chapter binding (an honest fallback, never a fabricated concept).
  * NOT_CHAPTER  — a topic identical to its own chapter buys nothing and is refused (keep the fallback).

A fact without a certified topic is NOT lost: it binds to its chapter exactly as before. So the change is
strictly additive and cannot reduce coverage.
"""
from __future__ import annotations

import json
import re
import sqlite3
from pathlib import Path
from typing import Dict, List, Optional

DEF_DIR = Path(__file__).parent / "topic_sets"

# Words that carry no discriminating meaning, so requiring them to be grounded would be noise.
_STOP = {
    "a", "an", "the", "of", "in", "on", "at", "to", "and", "or", "for", "from", "by", "with", "as", "is",
    "are", "its", "their", "it", "this", "that", "into", "between", "during", "per", "via",
}
_WORD = re.compile(r"[A-Za-z][A-Za-z'\-]*")


def _norm_words(s: str) -> List[str]:
    return [w.lower() for w in _WORD.findall(s or "")]


def _significant(topic: str) -> List[str]:
    # len >= 2 (not > 2): real science symbols are two characters — "Kp and Kc", "Cu", "pH".
    return [w for w in _norm_words(topic) if w not in _STOP and len(w) >= 2]


def _singulars(w: str) -> set:
    """Deterministic de-pluralisation candidates. Returns ALL plausible stems rather than committing to one:
    'nitriles' is 'nitrile' (drop -s) but 'boxes' is 'box' (drop -es), and no dictionary-free rule can tell
    them apart. Trying every candidate keeps grounding from failing on a correct topic."""
    out = set()
    if w.endswith("ies") and len(w) > 4:
        out.add(w[:-3] + "y")
    if w.endswith("es") and len(w) > 3:
        out.add(w[:-2])
    if w.endswith("s") and not w.endswith("ss") and len(w) > 2:
        out.add(w[:-1])
    return out


def evidence_text(fact: dict) -> str:
    """Everything the fact itself verified — the corpus a topic must be grounded in."""
    parts: List[str] = [fact.get("fact_text") or "", fact.get("answer_text") or "",
                        fact.get("concept_candidate") or ""]
    try:
        s = json.loads(fact.get("structured") or "{}")
    except Exception:
        s = {}
    for v in (s or {}).values():
        if isinstance(v, str):
            parts.append(v)
        elif isinstance(v, list):
            parts.extend(str(x) for x in v)
    try:
        p = json.loads(fact.get("provenance") or "{}")
        parts.append(p.get("stem_excerpt") or "")
        parts.append(p.get("chapter") or "")
    except Exception:
        pass
    return " ".join(parts)


def _variants(w: str) -> set:
    """Deterministic surface variants so grounding compares WORDS, not typography: plural/singular and the
    possessive ("Kepler's" vs "Kepler"). Never a synonym — a topic must use the evidence's own words."""
    out = {w} | _singulars(w)
    if "'" in w:
        bare = w.split("'")[0]
        out |= {bare} | _singulars(bare)
    return {x for x in out if x}


def grounding_gate(topic: str, fact: dict) -> dict:
    """Every significant topic word must occur in the fact's own verified evidence."""
    ev = set()
    for w in _norm_words(evidence_text(fact)):
        ev |= _variants(w)
    sig = _significant(topic)
    if not sig:
        return {"ok": False, "reason": "topic has no significant word"}
    missing = [w for w in sig if not (_variants(w) & ev)]
    return {"ok": not missing, "grounded": [w for w in sig if w not in missing],
            "reason": "" if not missing else f"not grounded in the fact's evidence: {missing}"}


def certify(topic: str, fact: dict) -> dict:
    """Run the mandatory topic gates. `status` is 'certified' only when every gate passes."""
    from kie.qie.qp_bridge import _clean_title
    from kie.qpgen import sanitize

    gates: Dict[str, dict] = {}
    t = (topic or "").strip()
    gates["present"] = {"ok": bool(t), "reason": "" if t else "no topic authored"}
    if not t:
        return {"status": "rejected", "gates": gates, "failed_gates": ["present"], "topic": None}

    cleaned = _clean_title(t)
    # An authored topic must survive AS AUTHORED. `_clean_title` may legitimately drop articles and dedupe a
    # repeated word — that is normalisation, not truncation. What must never happen is its 5-word cap
    # silencing a MEANINGFUL word: that is the "blindly truncated prose" the owner prohibited
    # ("Hydrolysis of a nitrile (from alkyl halide + KCN) with aqueous NaOH" -> "Hydrolysis of nitrile (from
    # alkyl"). So: every significant word of the authored topic must still be present after cleaning.
    kept = set(_norm_words(cleaned))
    lost = [w for w in _significant(t) if w not in kept]
    gates["not_truncated"] = {"ok": not lost,
                              "reason": "" if not lost
                              else f"cleaning to {cleaned!r} dropped {lost} — author a shorter topic, "
                                   f"never a truncation of prose"}
    gates["sanitizer"] = {"ok": sanitize.is_clean_concept(cleaned),
                          "reason": "" if sanitize.is_clean_concept(cleaned)
                          else "fails qpgen sanitize.is_clean_concept"}
    gates["subject"] = {"ok": bool(fact.get("subject")),
                        "reason": "" if fact.get("subject") else "fact has no gated subject"}
    gates["grounding"] = grounding_gate(t, fact)
    # Compare CLEANED vs CLEANED: qp_bridge cleans the chapter title too, so "Excretory Products And Their
    # Elimination" and its topic both normalise to the same string. Comparing a cleaned topic against a RAW
    # chapter silently passed a topic identical to its own chapter (it buys nothing but hides the fallback).
    chapter_raw = (fact.get("concept_candidate") or "").split("::")[-1].strip()
    same = cleaned.lower() == _clean_title(chapter_raw).lower()
    gates["not_chapter"] = {"ok": not same,
                            "reason": "" if not same
                            else "topic is its own chapter — keep the chapter binding instead"}

    mandatory = ("present", "not_truncated", "sanitizer", "subject", "grounding", "not_chapter")
    failed = [g for g in mandatory if not gates[g]["ok"]]
    return {"status": "certified" if not failed else "rejected", "gates": gates,
            "failed_gates": failed, "topic": cleaned}


def concept_key(fact: dict) -> str:
    """The concept a fact binds to: its certified TOPIC, else its chapter (honest fallback)."""
    t = (fact.get("topic") or "").strip()
    return f"{fact['subject']} :: {t}" if t else fact["concept_candidate"]


# ── committed topic sets (governance record; qie.db is a gitignored derived store) ────────────────────
def available() -> List[str]:
    return sorted(p.stem for p in DEF_DIR.glob("*.json")) if DEF_DIR.exists() else []


def load(name: str) -> dict:
    p = DEF_DIR / f"{name}.json"
    if not p.exists():
        raise FileNotFoundError(f"no such topic set {name!r}; available: {available()}")
    return json.loads(p.read_text())


def _facts_by_id(qconn: sqlite3.Connection) -> Dict[str, dict]:
    qconn.row_factory = sqlite3.Row
    return {r["fact_id"]: dict(r) for r in
            qconn.execute("SELECT * FROM governed_fact WHERE status='verified'")}


def apply_set(qconn: sqlite3.Connection, name: str, dry_run: bool = True) -> dict:
    """Certify each authored topic against its fact's own evidence and (unless dry) persist the survivors."""
    data = load(name)
    facts = _facts_by_id(qconn)
    out = {"set": name, "certified": 0, "rejected": 0, "missing_fact": 0,
           "verdicts": [], "reasons": {}}
    for row in data.get("topics", []):
        fid = row.get("fact_id")
        fact = facts.get(fid)
        if not fact:
            out["missing_fact"] += 1
            continue
        v = certify(row.get("topic"), fact)
        out["verdicts"].append({"fact_id": fid, "topic": row.get("topic"),
                                "status": v["status"], "failed_gates": v["failed_gates"]})
        if v["status"] != "certified":
            out["rejected"] += 1
            for g in v["failed_gates"]:
                out["reasons"][g] = out["reasons"].get(g, 0) + 1
            continue
        out["certified"] += 1
        if not dry_run:
            safe = {g: {k: x for k, x in d.items() if isinstance(x, (bool, str, int, float, list))}
                    for g, d in v["gates"].items()}
            qconn.execute("UPDATE governed_fact SET topic=?, topic_evidence=? WHERE fact_id=?",
                          (v["topic"], json.dumps({"gates": safe, "authored_by": data.get("authored_by"),
                                                   "set": name}), fid))
    if not dry_run:
        qconn.commit()
    return out


def coverage(qconn: sqlite3.Connection) -> dict:
    """How many distinct concepts the qualitative lane can bind — topics vs the chapter fallback."""
    qconn.row_factory = sqlite3.Row
    by: Dict[str, dict] = {}
    for r in qconn.execute("SELECT subject, concept_candidate, topic FROM governed_fact "
                           "WHERE status='verified'"):
        d = by.setdefault(r["subject"], {"facts": 0, "chapters": set(), "topics": set(),
                                         "fallback_chapters": set()})
        d["facts"] += 1
        d["chapters"].add(r["concept_candidate"])
        if (r["topic"] or "").strip():
            d["topics"].add(f"{r['subject']} :: {r['topic']}")
        else:
            d["fallback_chapters"].add(r["concept_candidate"])
    out = {}
    for s, d in by.items():
        out[s] = {"facts": d["facts"], "chapters": len(d["chapters"]), "topics": len(d["topics"]),
                  "fallback_chapters": len(d["fallback_chapters"]),
                  "bindable_concepts": len(d["topics"]) + len(d["fallback_chapters"])}
    return out


def _main(argv: List[str]) -> int:
    import argparse
    from kie import config
    ap = argparse.ArgumentParser(prog="kie.qie.convert.topics",
                                 description="Certify (and optionally apply) an authored topic set.")
    ap.add_argument("topic_set", nargs="?", help=f"one of {available()}")
    ap.add_argument("--apply", action="store_true", help="persist certified topics (default: dry run)")
    ap.add_argument("--coverage", action="store_true", help="show bindable-concept coverage")
    a = ap.parse_args(argv)
    conn = sqlite3.connect(str(config.KIE_HOME / "qie.db"))
    try:
        if a.coverage or not a.topic_set:
            for s, d in sorted(coverage(conn).items()):
                print(f"  {s:12s} facts={d['facts']:3d} chapters={d['chapters']:3d} "
                      f"topics={d['topics']:3d} fallback={d['fallback_chapters']:3d} "
                      f"-> bindable={d['bindable_concepts']:3d}")
            if not a.topic_set:
                print("\navailable topic sets:", ", ".join(available()) or "(none)")
            return 0
        r = apply_set(conn, a.topic_set, dry_run=not a.apply)
        for v in r["verdicts"]:
            if v["status"] != "certified":
                print(f"  REJECT  {v['topic']!r:40s} {v['failed_gates']}")
        print(f"\n{r['set']}: certified {r['certified']} / rejected {r['rejected']}"
              f"{' / missing fact ' + str(r['missing_fact']) if r['missing_fact'] else ''}"
              f"{'' if a.apply else '   (dry run — pass --apply)'}")
        if r["reasons"]:
            print("  reject reasons:", r["reasons"])
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv[1:]))
