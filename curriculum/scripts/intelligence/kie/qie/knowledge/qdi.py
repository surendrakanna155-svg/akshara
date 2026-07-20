"""STAGE 1.5 — CERTIFIED QUESTION DESIGN INTELLIGENCE, learned from owned real-exam evidence.

The curriculum index says WHAT may be asked. This layer says HOW a genuinely good question is BUILT —
the machinery that makes real JEE/NEET items hard, twisted, and genuinely multi-concept. Concept-only
generation cannot reach that quality, and the 1,000-spec trial showed why: the generator produced clean,
correct, class-appropriate items, but nothing in the planner told it what makes an item *good* rather than
merely valid.

SOURCE: ~20k already-chunked chunks of real NEET / JEE Main / JEE Advanced / AIIMS papers we own.
No re-download. No re-OCR. Read-only against kie.db.

THE TWO HARD RULES, ENFORCED IN CODE (not just asked for in a prompt):

1. **NEVER copy source wording.** `assert_no_copying()` compares every stored text field against the source
   chunk it was learned from, at the token-shingle level. A pattern that echoes the source is REJECTED as
   `copies_source_wording`, not stored. Structure is transferable; wording is not ours to reuse.

2. **AI interpretation is never automatic truth.** The analyst PROPOSES; an INDEPENDENT auditor that never
   saw the analyst's reasoning disposes. Only `accept` promotes to `certified`. This mirrors the governance
   already proven in the trial, where a blind judge caught a 25.3% curriculum-tag failure the gates missed.

Provenance (doc_id/chunk_id/exam/year) rides on every pattern so any design claim is traceable to the real
item that evidences it — without that item's words ever being stored.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from kie import config

QDI_SCHEMA = Path(__file__).resolve().parent / "qdi_schema.sql"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def open_qdi(conn: sqlite3.Connection) -> sqlite3.Connection:
    """QDI tables live alongside the knowledge index but are a DISTINCT namespace (qdi_*), never merged
    into ki_*. Curriculum evidence and design evidence must not contaminate one another."""
    conn.executescript(QDI_SCHEMA.read_text())
    conn.commit()
    return conn


# ── ANTI-COPYING GATE (deterministic; runs before anything is stored) ────────────────────────────────
_WORD = re.compile(r"[a-z0-9]+")


def _shingles(text: str, n: int = 5) -> Set[str]:
    w = _WORD.findall((text or "").lower())
    return {" ".join(w[i:i + n]) for i in range(max(0, len(w) - n + 1))}


def copying_score(candidate_text: str, source_text: str, n: int = 5) -> float:
    """Fraction of the candidate's n-gram shingles that appear verbatim in the source."""
    c = _shingles(candidate_text, n)
    if not c:
        return 0.0
    s = _shingles(source_text, n)
    if not s:
        return 0.0
    return len(c & s) / len(c)


def assert_no_copying(pattern: dict, source_text: str, threshold: float = 0.12) -> Optional[str]:
    """-> reason if the pattern echoes source wording, else None.

    Checks every free-text field a pattern stores. Abstract design language ("a state change mid-problem
    forces re-evaluation of the conserved quantity") shares almost no 5-gram shingles with a source stem;
    a copied or lightly-paraphrased stem shares many.
    """
    fields = [pattern.get("design_summary") or "", pattern.get("pattern_name") or ""]
    for key in ("reasoning_chain", "difficulty_mechanism", "transformation", "solution_structure",
                "constraints", "misconceptions"):
        v = pattern.get(key)
        if isinstance(v, list):
            fields += [str(x) for x in v]
    joined = " ".join(fields)
    score = copying_score(joined, source_text)
    if score >= threshold:
        return f"copies_source_wording: {score:.0%} of pattern shingles appear verbatim in the source chunk"
    # a stem-shaped sentence is a tell even when shingles miss (light paraphrase)
    for f in fields:
        if re.search(r"\b(find|calculate|evaluate|determine)\b.{0,80}\?$", f.strip(), re.I) and len(f) > 60:
            return "copies_source_wording: a field is phrased as a question stem rather than as design structure"
    return None


# ── source selection ────────────────────────────────────────────────────────────────────────────────
def exam_sources(kconn: sqlite3.Connection, subject: Optional[str] = None,
                 exams: Tuple[str, ...] = ("JEE_Main", "JEE_Advanced", "NEET", "AIIMS")) -> List[dict]:
    """Owned, already-chunked real exam papers. Never re-downloaded, never re-OCR'd."""
    out = []
    q = ("SELECT doc_id, rel_path, category, exam, subject, year, "
         "(SELECT COUNT(*) FROM chunks c WHERE c.doc_id=sd.doc_id) AS n "
         "FROM source_documents sd WHERE (category IN (%s) OR rel_path LIKE '%%Question_Bank%%' "
         "OR rel_path LIKE '%%Previous_Papers%%')" % ",".join("?" * len(exams)))
    args: List = list(exams)
    if subject:
        q += " AND (subject = ? OR rel_path LIKE ?)"
        args += [subject, f"%{subject.lower()}%"]
    for r in kconn.execute(q, args):
        if r["n"]:
            out.append({"doc_id": r["doc_id"], "rel_path": r["rel_path"], "exam": r["exam"] or r["category"],
                        "subject": r["subject"], "year": r["year"], "chunks": r["n"]})
    return sorted(out, key=lambda d: -d["chunks"])


def save_source(conn: sqlite3.Connection, s: dict) -> None:
    conn.execute("INSERT OR REPLACE INTO qdi_source (doc_id, rel_path, exam, subject, year, chunks, created_at) "
                 "VALUES (?,?,?,?,?,?,?)",
                 (s["doc_id"], s["rel_path"], s.get("exam"), s.get("subject"), s.get("year"),
                  s.get("chunks"), _now()))
    conn.commit()


# ── the analyst brief ───────────────────────────────────────────────────────────────────────────────
ANALYST_BRIEF = """\
You are a QUESTION DESIGN ANALYST. You are reading REAL previous-year exam questions (JEE Main / JEE
Advanced / NEET / AIIMS) that we own. Your job is to extract the ABSTRACT DESIGN MACHINERY that made each
good question work — so that ORIGINAL questions of the same calibre can be constructed later.

## THE TWO ABSOLUTE RULES
1. **NEVER reproduce the source question's wording, numbers, options, or phrasing.** Not in any field.
   You are extracting STRUCTURE, not text. Your output is machine-checked against the source: any field
   that echoes the source is rejected outright. If you find yourself writing "Find the value of x when...",
   stop — that is the question, not its design.
2. **Only claim what the evidence supports.** If a chunk is OCR sludge, or you cannot tell what the item's
   machinery was, do not guess — put it under `rejects`. A fabricated pattern silently corrupts every
   question generated from it.

## WHAT A DESIGN PATTERN IS
Not "a question about capacitors". A pattern is the reusable machinery:
  BAD  (too vague)    : "hard capacitor question"
  BAD  (copies source): "Two capacitors of 2 uF and 3 uF connected across 100 V, find final charge"
  GOOD (structure)    : pattern_name: "switched-state energy redistribution"
                        design_summary: "A system is set in one configuration and allowed to reach a
                        steady state; a switch/connection then changes the configuration. The candidate
                        must recognise that a conserved quantity carries across the change while a
                        non-conserved one does not, and re-derive the post-change state. Difficulty comes
                        from the implicit state change, not from arithmetic."

## FOR EACH PATTERN, EXTRACT WHERE THE EVIDENCE SUPPORTS IT
- `archetype`: from the canonical list you are given. Do not invent one.
- `concept_roles`: the ROLE each concept plays (e.g. {"role":"supplies the constraint","what_it_contributes":
  "fixes one unknown so the second relation becomes solvable"}). Roles, not just concept names.
- `composition_kind`: single | sequential_chain | constraint_coupled | state_change | inverse_construction | ...
- `dependency`: HOW concept B consumes concept A's output. This is what makes an item genuinely
  multi-concept rather than two topics named in one sentence. If there is no real dependency, say
  composition_kind = "single" — do NOT inflate it.
- `reasoning_chain`: the ordered ABSTRACT steps a solver must perform. No numbers, no source wording.
- `operators`: the relations/operations applied between concepts.
- `constraints`: constraint structures that must hold for the item to be well-posed.
- `difficulty_mechanism`: what ACTUALLY makes it hard. Be specific and honest. "ugly arithmetic" is NOT a
  difficulty mechanism — say so if that is all there is. Real ones: a non-obvious intermediate inference,
  an implicit state change, a constraint that must be discovered, a representation change, a trap that
  punishes a common shortcut.
- `transformation`: information transformation / indirect presentation (e.g. the quantity asked for is not
  the quantity given; data supplied in a graph rather than numerically; the unknown is embedded in a ratio).
- `distractor_structure`: for each wrong option that reveals a misconception — {"misconception": "<named
  student error>", "produces": "<what that error yields>"}. NAME the misconception. "other" is not an answer.
- `visual_archetype` + `visual_necessity`: only if a figure is genuinely load-bearing.
- `solution_structure`: the abstract shape of a solution that works for this pattern.
- `difficulty_band`: easy | moderate | hard, as evidenced by the item's role in a real paper.

Merge duplicates: if several real items share one machinery, emit ONE pattern with `evidence_refs` listing
each, and set `evidence_count`. A pattern evidenced by many real items is worth more than a one-off.

## OUTPUT — JSON array, no prose outside the JSON:
{"patterns": [ {..pattern fields.., "evidence_refs": [{"chunk_id":"...","exam":"JEE_Main"}], "evidence_count": 3} ],
 "rejects":  [ {"pattern_name":"...", "reject_class":"ocr_garbage|not_a_pattern|unsupported_by_evidence|relabelled_single_concept", "reason":"..."} ]}

## CANONICAL ARCHETYPES
{archetypes}

## REAL EXAM EVIDENCE
"""


def write_analyst_worksheet(kconn: sqlite3.Connection, chunk_rows: List[sqlite3.Row], path: str,
                            archetypes: Tuple[str, ...]) -> int:
    with open(path, "w") as f:
        f.write(ANALYST_BRIEF.replace("{archetypes}", ", ".join(archetypes)))
        for r in chunk_rows:
            f.write(json.dumps({
                "chunk_id": r["chunk_id"], "exam": r["exam"], "subject": r["subject"],
                "year": r["year"], "text": re.sub(r"\s+", " ", r["text"] or "")[:2600],
            }, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON object described above, over these {len(chunk_rows)} evidence chunks.\n")
    return len(chunk_rows)


def candidate_chunks(kconn: sqlite3.Connection, doc_ids: List[str], limit: int = 60) -> List[sqlite3.Row]:
    """Chunks that plausibly carry a real question + its answer. Deterministic pre-filter — the analyst
    should spend its tokens on interpretation, not on sifting page furniture."""
    if not doc_ids:
        return []
    q = ("SELECT c.chunk_id, c.text, sd.exam, sd.subject, sd.year FROM chunks c "
         "JOIN source_documents sd ON sd.doc_id = c.doc_id "
         "WHERE c.doc_id IN (%s) AND length(c.text) > 200 "
         "AND (c.text LIKE '%%Ans%%' OR c.text LIKE '%%(1)%%' OR c.text LIKE '%%(A)%%' OR c.text LIKE '%%Sol%%') "
         "ORDER BY length(c.text) DESC LIMIT ?" % ",".join("?" * len(doc_ids)))
    return kconn.execute(q, (*doc_ids, limit)).fetchall()


# ── ingest (analyst proposes) ───────────────────────────────────────────────────────────────────────
def _pid(exam: str, subject: str, name: str) -> str:
    return "QDP_" + hashlib.sha256(f"{exam}|{subject}|{name.strip().lower()}".encode()).hexdigest()[:14]


def ingest_patterns(conn: sqlite3.Connection, kconn: sqlite3.Connection, payload: dict,
                    exam: str, subject: str, model: str) -> Dict[str, int]:
    m = {"proposed": 0, "rejected_copying": 0, "rejected_by_analyst": 0, "malformed": 0}
    for p in payload.get("patterns") or []:
        name = (p.get("pattern_name") or "").strip()
        if not name:
            m["malformed"] += 1
            continue
        # A pattern IS its structured machinery; the prose summary is the least load-bearing field.
        # Accept a structure-complete pattern that omitted the prose, and compose the summary from the
        # structure rather than discarding real design intelligence over a missing string.
        if not (p.get("design_summary") or "").strip():
            chain = p.get("reasoning_chain") or []
            mech = p.get("difficulty_mechanism") or []
            if not chain and not mech:
                m["malformed"] += 1
                continue
            dep = p.get("dependency")
            p["design_summary"] = (
                f"Machinery: {p.get('composition_kind') or 'single'}. "
                + (f"Dependency: {json.dumps(dep)}. " if dep else "")
                + (f"Reasoning chain: {' -> '.join(str(c) for c in chain)}. " if chain else "")
                + (f"Difficulty arises from: {'; '.join(str(x) for x in mech)}." if mech else "")
            )[:1800]
            p["_summary_composed_from_structure"] = True

        # ANTI-COPYING GATE — compare against the actual source chunks this pattern claims to rest on
        refs = p.get("evidence_refs") or []
        src = ""
        for ref in refs[:4]:
            row = kconn.execute("SELECT text FROM chunks WHERE chunk_id=?", (ref.get("chunk_id"),)).fetchone()
            if row:
                src += " " + (row[0] or "")
        if src.strip():
            why = assert_no_copying(p, src)
            if why:
                _reject_pattern(conn, exam, subject, name, "copies_source_wording", why,
                                json.dumps(refs), f"deterministic")
                m["rejected_copying"] += 1
                continue

        pid = _pid(exam, subject, name)
        conn.execute(
            "INSERT OR REPLACE INTO qdi_pattern (pattern_id, exam, subject, archetype, pattern_name, "
            "design_summary, concept_roles, composition_kind, dependency, reasoning_chain, step_depth, "
            "operators, constraints, difficulty_mechanism, transformation, difficulty_band, "
            "distractor_structure, misconceptions, visual_archetype, visual_necessity, solution_structure, "
            "evidence_refs, evidence_count, analyst_model, status, created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (pid, exam, subject, p.get("archetype") or "", name, p.get("design_summary"),
             json.dumps(p.get("concept_roles") or []), p.get("composition_kind"),
             json.dumps(p.get("dependency") or {}), json.dumps(p.get("reasoning_chain") or []),
             len(p.get("reasoning_chain") or []) or None, json.dumps(p.get("operators") or []),
             json.dumps(p.get("constraints") or []), json.dumps(p.get("difficulty_mechanism") or []),
             json.dumps(p.get("transformation") or []), p.get("difficulty_band"),
             json.dumps(p.get("distractor_structure") or []), json.dumps(p.get("misconceptions") or []),
             p.get("visual_archetype"), p.get("visual_necessity"),
             json.dumps(p.get("solution_structure") or []), json.dumps(refs),
             int(p.get("evidence_count") or len(refs) or 1), model, "proposed", _now()))
        m["proposed"] += 1

    for r in payload.get("rejects") or []:
        _reject_pattern(conn, exam, subject, r.get("pattern_name") or "?", r.get("reject_class") or "not_a_pattern",
                        r.get("reason"), json.dumps(r.get("evidence_refs") or []), f"analyst({model})")
        m["rejected_by_analyst"] += 1
    conn.commit()
    return m


def _reject_pattern(conn, exam, subject, name, cls, reason, refs, by) -> None:
    rid = "QRJ_" + hashlib.sha256(f"{exam}|{subject}|{name}|{by}".encode()).hexdigest()[:16]
    conn.execute("INSERT OR REPLACE INTO qdi_rejected (reject_id, exam, subject, pattern_name, reject_class, "
                 "reason, evidence_refs, rejected_by, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
                 (rid, exam, subject, name[:200], cls, (reason or "")[:400], refs, by, _now()))


# ── independent audit (disposes) ────────────────────────────────────────────────────────────────────
QDI_AUDIT_BRIEF = """\
You are an INDEPENDENT DESIGN AUDITOR. Another model proposed these question-design patterns from real
exam papers. You did not write them and cannot see its reasoning. Refuse anything that should not become
design intelligence — every future generated question will be built from what you accept.

Reject a pattern if ANY of these hold:
- it reproduces or lightly paraphrases a specific source question instead of abstracting its machinery
  (a pattern should describe MACHINERY; if you can reconstruct the original item from it, reject)
- it is a topic label ("hard capacitor question") rather than a reusable construction mechanism
- `composition_kind` claims a real dependency but `dependency` shows none — a relabelled single-concept item
- `difficulty_mechanism` is empty, vacuous, or amounts to "the arithmetic is messy" (that is not difficulty)
- `distractor_structure` names no real misconception (an unnamed "other" is not a misconception)
- the reasoning_chain is not actually the chain that solves that kind of item
- it is unsupported by the cited evidence, or is a duplicate of another pattern

Accepting a bad pattern is far worse than quarantining a good one. Default to `quarantine` on genuine
uncertainty and `reject` on anything vacuous.

OUTPUT — JSON array, pattern_id copied EXACTLY, no prose outside the JSON:
{"pattern_id":"QDP_...","verdict":"accept|reject|quarantine","reasons":"<one sentence; REQUIRED unless accept>"}

## PATTERNS
"""


def write_qdi_audit_worksheet(conn: sqlite3.Connection, path: str, exam: str, subject: str) -> int:
    rows = conn.execute(
        "SELECT pattern_id, archetype, pattern_name, design_summary, concept_roles, composition_kind, "
        "dependency, reasoning_chain, operators, constraints, difficulty_mechanism, transformation, "
        "difficulty_band, distractor_structure, visual_archetype, visual_necessity, solution_structure, "
        "evidence_count FROM qdi_pattern WHERE exam=? AND subject=? AND status='proposed'", (exam, subject)
    ).fetchall()
    with open(path, "w") as f:
        f.write(QDI_AUDIT_BRIEF)
        for r in rows:
            d = {k: r[k] for k in r.keys()}
            for j in ("concept_roles", "dependency", "reasoning_chain", "operators", "constraints",
                      "difficulty_mechanism", "transformation", "distractor_structure", "solution_structure"):
                try:
                    d[j] = json.loads(d[j] or "[]")
                except Exception:
                    pass
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(rows)} verdict objects.\n")
    return len(rows)


def ingest_qdi_audit(conn: sqlite3.Connection, payload: List[dict], model: str) -> Dict[str, int]:
    m = {"in": 0, "certified": 0, "rejected": 0, "quarantined": 0, "unmatched": 0}
    for v in payload:
        pid = v.get("pattern_id")
        row = conn.execute("SELECT pattern_id, exam, subject, pattern_name FROM qdi_pattern WHERE pattern_id=?",
                           (pid,)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        m["in"] += 1
        verdict = v.get("verdict") or "quarantine"
        status = {"accept": "certified", "reject": "rejected", "quarantine": "quarantined"}.get(verdict, "quarantined")
        conn.execute("UPDATE qdi_pattern SET audit_verdict=?, audit_reasons=?, audit_model=?, status=? "
                     "WHERE pattern_id=?", (verdict, (v.get("reasons") or "")[:400], model, status, pid))
        if verdict == "reject":
            _reject_pattern(conn, row["exam"], row["subject"], row["pattern_name"], "unsupported_by_evidence",
                            v.get("reasons"), "[]", f"audit({model})")
        m[status] += 1
    conn.commit()
    return m


def certified_patterns(conn: sqlite3.Connection, subject: str, archetype: Optional[str] = None,
                       difficulty: Optional[str] = None) -> List[dict]:
    """The ONLY design intelligence a generation brief may use."""
    q = "SELECT * FROM qdi_pattern WHERE subject=? AND status='certified'"
    args: List = [subject]
    if archetype:
        q += " AND archetype=?"
        args.append(archetype)
    if difficulty:
        q += " AND difficulty_band=?"
        args.append(difficulty)
    out = []
    for r in conn.execute(q + " ORDER BY evidence_count DESC", args):
        d = {k: r[k] for k in r.keys()}
        for j in ("concept_roles", "reasoning_chain", "operators", "constraints", "difficulty_mechanism",
                  "transformation", "distractor_structure", "solution_structure", "evidence_refs"):
            try:
                d[j] = json.loads(d[j] or "[]")
            except Exception:
                pass
        out.append(d)
    return out
