"""The Certified Knowledge Index BUILD driver — one discipline at a time, resumable at every step.

    python -m kie.qie.knowledge.build spine    <Subject>     # deterministic: books + chapters + rejects
    python -m kie.qie.knowledge.build sheet    <Subject> <book_code>   # worksheet for the engineer
    python -m kie.qie.knowledge.build ingest   <book_code> <json>      # ingest engineer output
    python -m kie.qie.knowledge.build audit    <Subject> [class]       # worksheet for the INDEPENDENT audit
    python -m kie.qie.knowledge.build verdicts <json>                  # ingest audit verdicts -> certify
    python -m kie.qie.knowledge.build report   [Subject]               # coverage

`Subject` is the CURRICULUM SOURCE subject — Mathematics | Science | Physics | Chemistry | Biology.
'Science' is the integrated classes 6-10 book; its concepts carry an inferred academic discipline.

The model never writes to the database. It reads a worksheet and returns JSON; deterministic code decides
what is stored, and only an INDEPENDENT audit pass promotes anything to `certified`.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

from kie import config
from kie.qie.knowledge import engineer as E
from kie.qie.knowledge import schema as SC
from kie.qie.knowledge import spine as S

SHEETS = config.KIE_HOME / "reports" / "knowledge_sheets"
SUBJECTS = ("Mathematics", "Science", "Physics", "Chemistry", "Biology")


def _kie() -> sqlite3.Connection:
    # kie.db (the owned substrate) is only ever READ here (chunks); open it read-only so the build lane
    # can never mutate the substrate and no -wal is created against it (R1-5).
    c = sqlite3.connect(f"file:{config.DB_PATH}?mode=ro", uri=True)
    c.row_factory = sqlite3.Row
    return c


def _book(k, code: str) -> dict:
    for subj in SUBJECTS:
        for b in S.admitted_books(k, subj):
            if b["book_code"] == code:
                return b
    raise SystemExit(f"unknown book_code {code!r}")


def _record_unusable_books(k, conn, subject: str) -> int:
    """A book this subject SHOULD have, that carries no owned evidence at all.

    `admitted_books` skips these silently because they have no chunks. Silence is the wrong answer: a
    corrupt source is a permanent, reportable hole in curriculum coverage (class-12 Chemistry part 2 is
    'not a zip file', so every concept in it is unindexable), and coverage maths must subtract it rather
    than quietly shrink the denominator.
    """
    n = 0
    for r in k.execute("SELECT doc_id, rel_path, certify_status, certify_reason, parser_class "
                       "FROM source_documents"):
        subj, cls, _basis, _integrated = S.classify_book(r["rel_path"])
        if subj != subject or cls is None:
            continue
        if k.execute("SELECT COUNT(*) FROM chunks WHERE doc_id=?", (r["doc_id"],)).fetchone()[0]:
            continue
        code = (S._NCERT.search(r["rel_path"]) or [None])
        code = r["rel_path"].split("_")[-1].replace(".zip", "") if code else "?"
        SC.record_gap(conn, f"{subject}|{cls}|{code}", "corrupt_source",
                      f"{r['certify_reason'] or 'no chunks'} (parser_class={r['parser_class']}); "
                      f"0 chunks — no owned evidence exists for this book",
                      f"{subject} class {cls}: every concept in this volume")
        print(f"  {code:10s} class {cls:2d}  BLOCKED — {r['certify_reason'] or 'no chunks'}")
        n += 1
    return n


def cmd_spine(subject: str) -> None:
    """Deterministic pass: persist the books, their chapters and every deterministic reject."""
    k, conn = _kie(), E.open_index()
    books = S.admitted_books(k, subject)
    _record_unusable_books(k, conn, subject)
    if not books:
        raise SystemExit(f"no admitted books for {subject!r}")
    tot_ch = tot_tp = tot_rj = 0
    for b in books:
        sp, rejects = S.extract_spine(k, b["doc_id"])
        E.save_book(conn, b)
        if not sp:
            SC.record_gap(conn, f"{subject}|{b['taught_at_class']}|{b['book_code']}", "no_spine",
                          "no numbered curriculum heading found anywhere in this book",
                          f"{subject} class {b['taught_at_class']}")
            SC.mark(conn, b["doc_id"], "spine", "blocked", "no numbered headings")
            print(f"  {b['book_code']:10s} class {b['taught_at_class']:2d}  BLOCKED — no numbered headings")
            continue
        n_tp = sum(len(c["topics"]) for c in sp.values())
        E.save_deterministic_rejects(conn, b, rejects)
        SC.mark(conn, b["doc_id"], "spine", "done", f"{len(sp)} chapters, {n_tp} topics")
        tot_ch += len(sp); tot_tp += n_tp; tot_rj += len(rejects)
        print(f"  {b['book_code']:10s} class {b['taught_at_class']:2d}  chapters={len(sp):3d} "
              f"topics={n_tp:4d} rejects={len(rejects):4d}  [{','.join(sorted({S.extraction_basis(c) for c in sp.values()}))}]")
    print(f"\n{subject}: {len(books)} books, {tot_ch} chapters, {tot_tp} numbered topics, {tot_rj} rejects")


def cmd_sheet(subject: str, code: str) -> None:
    k, conn = _kie(), E.open_index()
    b = _book(k, code)
    sp, _ = S.extract_spine(k, b["doc_id"])
    chapters = [dict(chapter_no=n, subject=b["subject"], taught_at_class=b["taught_at_class"],
                     book_code=b["book_code"], is_integrated=b["is_integrated"], **sp[n])
                for n in sorted(sp)]
    SHEETS.mkdir(parents=True, exist_ok=True)
    path = SHEETS / f"engineer_{code}.txt"
    n = E.write_engineer_worksheet(k, chapters, str(path), book=b)
    SC.mark(conn, b["doc_id"], "engineer", "in_progress", f"{n} chapters -> {path.name}")
    print(f"{path}\nchapters={n} class={b['taught_at_class']} subject={b['subject']} "
          f"integrated={b['is_integrated']}")


def cmd_ingest(code: str, payload_path: str, force: str = None) -> None:
    """Ingest engineer output. Re-proposing a concept RESETS it to `proposed` — by design, since a fresh
    proposal must face a fresh independent audit. That also means a careless re-run silently de-certifies
    work, so an already-ingested book needs an explicit `force`."""
    k, conn = _kie(), E.open_index()
    b = _book(k, code)
    if SC.is_done(conn, b["doc_id"], "engineer") and force != "force":
        n = conn.execute("SELECT COUNT(*) FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
                         "WHERE ch.doc_id=? AND c.status='certified'", (b["doc_id"],)).fetchone()[0]
        raise SystemExit(f"{code}: engineer already ingested ({n} certified). Re-ingest would reset those "
                         f"to 'proposed' and require a fresh audit. Pass 'force' if that is intended.")
    sp, _ = S.extract_spine(k, b["doc_id"])
    payload = json.loads(Path(payload_path).read_text())
    m = E.ingest_engineer(conn, k, payload, b, sp, model="opus-4.8(engineer)")
    SC.mark(conn, b["doc_id"], "engineer", "done", json.dumps(m))
    print(f"{code}: {m}")


def cmd_retire(subject: str, code: str = None) -> None:
    """Quarantine records from an earlier build of the SAME books that this rebuild did not re-propose.

    When a book is re-engineered from a corrected spine, any surviving row for that book that the new pass
    did NOT emit is not independent corroboration — it is a stale opinion from the old extraction. Usually
    it is the same concept under the old name ("A Lakh Varieties!" vs "The Number One Lakh"), so leaving it
    `certified` seeds DUPLICATE concepts into the permanent foundation and re-imports exactly the evidence
    the rebuild exists to discard.

    Quarantined, never deleted: rejected knowledge stays permanently available for audit.

    Pass `code` to scope the retire to a SINGLE re-engineered book — required when re-running one book of a
    subject whose OTHER books are already certified and must NOT be touched (a full-subject retire would
    wrongly quarantine every one of them).
    """
    k, conn = _kie(), E.open_index()
    if code:
        docs = [_book(k, code)["doc_id"]]
    else:
        docs = [b["doc_id"] for b in S.admitted_books(k, subject) if SC.is_done(conn, b["doc_id"], "engineer")]
    if not docs:
        raise SystemExit(f"no re-engineered books for {subject!r} — nothing to retire against")
    q = ",".join("?" * len(docs))
    now = SC.now()
    cur = conn.execute(
        f"UPDATE ki_concept SET status='quarantined', audit_verdict='quarantine', "
        f"audit_reasons='superseded: this book was re-engineered from the corrected multi-channel spine on "
        f"{now} and this record was NOT re-proposed. It rests on the old extraction (chapter-level evidence, "
        f"pre-bugfix headings) and is most likely the same concept under a different canonical name.', "
        f"audit_model='deterministic(retire)' "
        f"WHERE subject=? AND status='certified' AND chapter_id IN "
        f"(SELECT chapter_id FROM ki_chapter WHERE doc_id IN ({q}))", [subject] + docs)
    conn.commit()
    print(f"{subject}: retired {cur.rowcount} superseded records from {len(docs)} re-engineered books")


def cmd_audit(subject: str, cls: str = None) -> None:
    k, conn = _kie(), E.open_index_ro()   # read-only: only writes a worksheet FILE, never the index
    SHEETS.mkdir(parents=True, exist_ok=True)
    c = int(cls) if cls else None
    path = SHEETS / f"audit_{subject}{'_c' + str(c) if c else ''}.txt"
    n = E.write_audit_worksheet(conn, str(path), subject, cls=c, kconn=k)
    print(f"{path}\nproposed records awaiting audit={n}")


def cmd_verdicts(payload_path: str) -> None:
    # kconn (read-only kie.db) is REQUIRED: the deterministic evidence gate resolves + sha-checks +
    # substance-checks each would-be-certified concept before promotion (R1-4). Refuses on a frozen index.
    k, conn = _kie(), E.open_index()
    payload = json.loads(Path(payload_path).read_text())
    m = E.ingest_audit(conn, payload, model="opus-4.8(independent-audit)", kconn=k)
    print(m)


def cmd_report(subject: str = None) -> None:
    """Coverage against a TRANSPARENT DENOMINATOR.

    `expected` = the numbered headings the BOOK ITSELF printed, recomputed live from the owned chunks.
    That is the only denominator that cannot flatter us: it does not shrink when extraction does badly,
    and a corrupt book contributes 0 expected AND is named in GAPS rather than silently vanishing.
    """
    k, conn = _kie(), E.open_index_ro()   # pure read: coverage report never writes the index
    subjects = [subject] if subject else list(SUBJECTS)

    # THE DENOMINATOR: the numbered SECTIONS the books themselves printed, recomputed live from the owned
    # chunks. Coverage is "how many of those sections produced a certified concept" — NOT concepts/topics,
    # which is not a ratio at all: one section legitimately teaches several concepts (§3.6 "Inverse
    # Proportions" teaches direct AND inverse proportion), so that reads 149% and means nothing.
    printed = {}
    for s in subjects:
        for b in S.admitted_books(k, s):
            sp, _ = S.extract_spine(k, b["doc_id"])
            key = (s, b["taught_at_class"])
            printed.setdefault(key, set())
            for n, ch in sp.items():
                printed[key] |= {f"{b['book_code']}:{sec}" for sec in ch["topics"]}

    print("── CURRICULUM SOURCE (proven from the NCERT filename code) ─────────────────────────────")
    print("   coverage = printed sections with >=1 CERTIFIED concept / sections the book printed")
    print(f"{'subject':12s} {'cls':>3s} {'chapt':>5s} {'sect':>5s} {'covrd':>5s} {'certif':>6s} "
          f"{'quar':>4s} {'rej':>4s} {'prop':>4s} {'cover':>6s}")
    tot_e = tot_c = tot_sec = tot_cov = 0
    for s in subjects:
        for cls in sorted({c for (sub, c) in printed if sub == s}):
            r = conn.execute(
                "SELECT SUM(status='certified') c, SUM(status='quarantined') q, SUM(status='rejected') r,"
                " SUM(status='proposed') p FROM ki_concept WHERE subject=? AND taught_at_class=?",
                (s, cls)).fetchone()
            ch = conn.execute("SELECT COUNT(*) FROM ki_chapter WHERE subject=? AND taught_at_class=?",
                              (s, cls)).fetchone()[0]
            # which printed sections actually produced a certified concept
            covered = set()
            for row in conn.execute(
                    "SELECT c.section_heading, src.book_code FROM ki_concept c "
                    "JOIN ki_chapter chp ON chp.chapter_id=c.chapter_id "
                    "JOIN ki_source src ON src.doc_id=chp.doc_id "
                    "WHERE c.subject=? AND c.taught_at_class=? AND c.status='certified'", (s, cls)):
                key = E._section_key(row["section_heading"])
                if key:
                    covered.add(f"{row['book_code']}:{key}")
            secs = printed[(s, cls)]
            cov = len(covered & secs)
            c_, q_, r_, p_ = (r["c"] or 0), (r["q"] or 0), (r["r"] or 0), (r["p"] or 0)
            tot_e += len(secs); tot_c += c_; tot_sec += len(secs); tot_cov += cov
            pct = f"{100.0 * cov / len(secs):5.1f}%" if secs else "   n/a"
            print(f"{s:12s} {cls:3d} {ch:5d} {len(secs):5d} {cov:5d} {c_:6d} {q_:4d} {r_:4d} {p_:4d} {pct:>6s}")

    print("\n── ACADEMIC DISCIPLINE (second, independent dimension) ─────────────────────────────")
    for r in conn.execute(
            "SELECT academic_discipline d, COUNT(*) n, SUM(status='certified') c, "
            "ROUND(AVG(discipline_confidence),2) conf FROM ki_concept GROUP BY academic_discipline "
            "ORDER BY n DESC"):
        print(f"  {str(r['d'] or '(unassigned)'):18s} total={r['n']:4d} certified={r['c'] or 0:4d} "
              f"avg_confidence={r['conf']}")
    print("\n  Science books, discipline x class (curriculum source stays 'Science'):")
    for r in conn.execute(
            "SELECT taught_at_class cls, academic_discipline d, COUNT(*) n, SUM(status='certified') c "
            "FROM ki_concept WHERE subject='Science' GROUP BY cls, d ORDER BY cls, n DESC"):
        print(f"    class {r['cls']:2d}  {str(r['d']):18s} {r['n']:4d} concepts, {r['c'] or 0:4d} certified")

    print("\n── REJECTED KNOWLEDGE (kept permanently as evidence) ───────────────────────────────")
    for r in conn.execute("SELECT reject_class, COUNT(*) n FROM ki_rejected GROUP BY reject_class "
                          "ORDER BY n DESC"):
        print(f"  {r['reject_class']:20s} {r['n']:5d}")

    print("\n── GENUINE BLOCKERS ────────────────────────────────────────────────────────────────")
    rows = conn.execute("SELECT scope, kind, detail, blocks FROM ki_gap ORDER BY scope").fetchall()
    for r in rows:
        print(f"  {r['scope']:26s} [{r['kind']}]\n      {r['detail'][:96]}\n      blocks: {r['blocks']}")
    if not rows:
        print("  (none)")

    if tot_sec:
        print(f"\nCERTIFIED CONCEPTS: {tot_c}")
        print(f"SECTION COVERAGE  : {tot_cov} / {tot_sec} printed sections carry a certified concept "
              f"({100.0 * tot_cov / tot_sec:.1f}%)")


DUP_BRIEF = """\
You are an INDEPENDENT CURRICULUM AUDITOR performing an INTEGRITY RE-AUDIT of records that are ALREADY
CERTIFIED but carry a known defect signature.

THE SIGNATURE: each record below has an `evidence` window that is (near-)IDENTICAL to another record's.
That is the extractor's mis-anchor fingerprint — the right heading prefixed to the WRONG body chunk (a
sibling's text, a parent's child's, or the chapter preview). Two independent audits converged on this, and
one caught a record whose sub-concepts spelled out "ZIFT / GIFT / ICSI" in full while its attached text
never mentioned them. Such records read as PLAUSIBLE; only comparing the claim against the attached text
exposes them.

Typically the FIRST record in a collision is genuinely covered and the LATER one is not — but verify, do
not assume.

YOUR TEST, per record: does THIS record's OWN `evidence` actually TEACH the concept in `canonical_name`
and support its `sub_concepts`?
- YES -> "keep"  (it stays certified)
- NO  -> "quarantine" (real concept, but its evidence does not teach it; it must not stay certified)
Never certify on a promise that the content lives in another section. Owner rule: never certify without
owned evidence; never use model memory as evidence.

OUTPUT — JSON array, concept_id copied EXACTLY, no prose outside the JSON:
{"concept_id":"KC_...","verdict":"keep|quarantine","reasons":"<one short sentence; REQUIRED for quarantine>"}

## RECORDS
"""


def cmd_dupaudit(out: str = None) -> None:
    """Worksheet for an integrity re-audit of CERTIFIED records whose evidence duplicates a sibling's."""
    k, conn = _kie(), E.open_index_ro()   # read-only: only writes a worksheet FILE, never the index
    SHEETS.mkdir(parents=True, exist_ok=True)
    path = SHEETS / (out or "audit_duplicate_evidence.txt")
    n = 0
    with open(path, "w") as f:
        f.write(DUP_BRIEF)
        for subj in SUBJECTS:
            for b in S.admitted_books(k, subj):
                rows = conn.execute(
                    "SELECT c.concept_id, c.canonical_name, c.taught_at_class, c.sub_concepts, c.boundary, "
                    "c.section_heading, c.evidence_chunks, ch.title AS chapter_title FROM ki_concept c "
                    "JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
                    "WHERE ch.doc_id=? AND c.status='certified' ORDER BY c.concept_id", (b["doc_id"],)
                ).fetchall()
                if len(rows) < 2:
                    continue
                recs = [{"evidence": E._evidence_for(k, r["evidence_chunks"], heading=r["section_heading"])}
                        for r in rows]
                dups = E.duplicate_evidence_groups(recs)
                for idx, src in dups.items():
                    r = rows[idx]
                    f.write(json.dumps({
                        "concept_id": r["concept_id"], "book": b["book_code"],
                        "subject": subj, "taught_at_class": r["taught_at_class"],
                        "chapter": r["chapter_title"], "canonical_name": r["canonical_name"],
                        "section_heading": r["section_heading"],
                        "sub_concepts": json.loads(r["sub_concepts"] or "[]"),
                        "duplicates_the_evidence_of": rows[src]["canonical_name"],
                        "evidence": recs[idx]["evidence"],
                    }, ensure_ascii=False) + "\n")
                    n += 1
        f.write(f"\nReturn ONLY the JSON array of {n} verdict objects.\n")
    print(f"{path}\ncertified records with duplicate-evidence signature = {n}")


def cmd_dupverdicts(payload_path: str) -> None:
    """Apply integrity re-audit verdicts: `quarantine` demotes a certified record; `keep` leaves it."""
    conn = E.open_index()
    payload = json.loads(Path(payload_path).read_text())
    m = {"keep": 0, "quarantined": 0, "unmatched": 0}
    for v in payload:
        cid = v.get("concept_id")
        row = conn.execute("SELECT status FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        if v.get("verdict") == "quarantine":
            conn.execute(
                "UPDATE ki_concept SET status='quarantined', audit_verdict='quarantine', audit_reasons=?, "
                "audit_model='opus-4.8(duplicate-evidence integrity re-audit)' WHERE concept_id=?",
                (f"integrity re-audit: {(v.get('reasons') or '')[:300]}", cid))
            m["quarantined"] += 1
        else:
            m["keep"] += 1
    conn.commit()
    print(m)


def freeze_index(version: str, index_path=None, kie_path=None) -> dict:
    """The SANCTIONED freeze — the ONLY committed writer of the ki_meta freeze keys (v1.4's were written
    ad-hoc). In ONE transaction it (1) recomputes the certified-knowledge fingerprint (never count-only),
    (2) records the substrate fingerprint of kie.db, (3) sanitizes stale legacy artefacts (index-resident
    qdi_* tables + the unversioned/legacy meta keys), and (4) flips immutability. Opens the index with the
    unfreeze hatch — this IS the sanctioned version-bump path — so it is exempt from the R1-5 freeze guard.

    NON-DESTRUCTIVE to prior versions: earlier fingerprints stay recorded (as v1.2/v1.3 already are)."""
    conn = E.open_index(index_path, unfreeze=True)
    kp = str(kie_path or config.DB_PATH)
    k = sqlite3.connect(f"file:{kp}?mode=ro", uri=True)
    try:
        content_fp = SC.certified_content_fingerprint(conn)
        substrate_fp = SC.compute_substrate_fingerprint(k)
        n_cert = conn.execute("SELECT COUNT(*) FROM ki_concept WHERE status='certified'").fetchone()[0]
        n_chunks = k.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
        san = SC.sanitize_legacy(conn)
        stamp = SC.now()
        meta = {
            "frozen_version": version,
            "immutable": "true",
            "immutable_since": stamp,
            "frozen_at": stamp,
            "certified_count_at_freeze": str(n_cert),
            f"certified_knowledge_fingerprint_{version}": content_fp,
            "certified_knowledge_fingerprint_method": SC.CONTENT_FP_METHOD,
            f"substrate_fingerprint_{version}": substrate_fp,
            "substrate_fingerprint_method": SC.SUBSTRATE_FP_METHOD,
            "substrate_chunks_at_freeze": str(n_chunks),
            "qdi_seed_role": "dropped_legacy_seed (real design-intelligence lane = qdi.db)",
        }
        for kk, vv in meta.items():
            conn.execute("INSERT OR REPLACE INTO ki_meta (key, value) VALUES (?,?)", (kk, vv))
        conn.commit()
    finally:
        conn.close()
        k.close()
    return {"version": version, "certified": n_cert, "content_fingerprint": content_fp,
            "substrate_fingerprint": substrate_fp, "chunks": n_chunks, **san}


def cmd_freeze(version: str, index_path: str = None) -> None:
    """CLI: freeze the CURRENT index state as <version>. ⚠ writes ki_meta + flips immutability — only run
    against a copy or a genuinely-intended version bump (see remediation.rebuild_v15 for the v1.5 flow)."""
    m = freeze_index(version, index_path)
    print(f"FROZEN {m['version']}: certified={m['certified']} "
          f"content_fp={m['content_fingerprint'][:12]}… substrate_fp={m['substrate_fingerprint'][:12]}… "
          f"chunks={m['chunks']} dropped={m['dropped_tables']} meta_keys_removed={m['meta_keys_removed']}")


def cmd_reconcile(subject: str = None) -> None:
    """Completeness proof: every printed section must resolve to a disposition. Flag silent omissions."""
    from kie.qie.knowledge import reconcile as RC
    reps = RC.reconcile_all([subject] if subject else None)
    tot = {}
    print(f"{'book':10s} {'subj':11s} {'cls':>3s} {'official':>8s}  "
          f"cert/merg/prop/quar/rej/toc?/OMIT")
    for rep in reps:
        c = rep["counts"]
        for kk, vv in c.items():
            tot[kk] = tot.get(kk, 0) + vv
        omit = c["OMISSION"] + c["in_toc_not_extracted"]
        flag = "  <== OMISSIONS" if omit else ""
        print(f"{rep['book']:10s} {rep['subject']:11s} {rep['class']:3d} {rep['n_official']:8d}  "
              f"{c['certified']}/{c['merged']}/{c['proposed']}/{c['quarantined']}/{c['rejected']}/"
              f"{c['in_toc_not_extracted']}/{c['OMISSION']}{flag}")
    print(f"\nCORPUS: {tot}")
    print("\nOMISSIONS (sections with no disposition — must be resolved before FREEZE):")
    for rep in reps:
        oms = [r for r in rep["rows"] if r[1] in ("OMISSION", "in_toc_not_extracted")]
        if oms:
            print(f"  {rep['book']} (C{rep['class']}): " +
                  ", ".join(f"{r[0]}[{r[2][:22]}]" for r in oms[:12]))


def main(argv) -> None:
    if not argv:
        raise SystemExit(__doc__)
    cmd, rest = argv[0], argv[1:]
    fn = {"spine": cmd_spine, "sheet": cmd_sheet, "ingest": cmd_ingest, "audit": cmd_audit,
          "verdicts": cmd_verdicts, "report": cmd_report, "retire": cmd_retire,
          "reconcile": cmd_reconcile, "dupaudit": cmd_dupaudit,
          "dupverdicts": cmd_dupverdicts, "freeze": cmd_freeze}.get(cmd)
    if not fn:
        raise SystemExit(__doc__)
    fn(*rest)


if __name__ == "__main__":
    main(sys.argv[1:])
