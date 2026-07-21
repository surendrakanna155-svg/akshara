"""Remediation R3-5 — read-only alias / name / prerequisite collision audit over the knowledge index.

WHY (audit #knowledge-ia-5 / #knowledge-ia-10): concept references in the index are still NAME strings —
`aliases`, `prerequisites` — not concept_ids. The certification audit measured 5 certified aliases that
collide with other canonical names and 53-95 ambiguous prerequisite references (a name that resolves to
more than one concept, or to none). Name-matching over that is silently wrong: the wrong node gets linked,
or a real prerequisite resolves to nothing. This module is the durable, deterministic report of exactly
those collisions, plus the id-based resolver (`resolve_name_to_concept_ids`) that should be preferred
wherever code currently name-matches.

PURE + READ-ONLY. It opens the (possibly frozen) index `?mode=ro` and only SELECTs — it never migrates,
never writes, and cannot breach the R1-5 freeze. It mutates nothing, so it is safe to run over the live
v1.5 index. The reported numbers are honest facts about the current index, not a target to drive to zero
here: fixing them (a derived name->id edge table) is R5-1/R5-2, downstream of this halt.

Usage (from curriculum/scripts/intelligence/):
    ../../.venv/bin/python -m kie.qie.remediation.alias_audit [index.db] [--status certified|*]
"""
from __future__ import annotations

import json
import re
import sqlite3
import sys

from kie import config


def _norm(s) -> str:
    """Same normalisation spine.concept_id hashes on: strip + lower + collapse internal whitespace."""
    return re.sub(r"\s+", " ", (s or "").strip().lower())


def _load_list(s) -> list:
    try:
        v = json.loads(s or "[]")
        return v if isinstance(v, list) else []
    except (ValueError, TypeError):
        return []


def _load_concepts(iconn, status: str = "certified") -> list:
    """Read the concept rows in scope. status='*' audits every row; otherwise only that status."""
    where, args = ("", ())
    if status != "*":
        where, args = (" WHERE status=?", (status,))
    rows = iconn.execute(
        "SELECT concept_id, subject, taught_at_class, canonical_name, aliases, prerequisites, status "
        "FROM ki_concept" + where, args).fetchall()
    out = []
    for r in rows:
        aliases = [a for a in _load_list(r["aliases"]) if isinstance(a, str)]
        out.append({
            "concept_id": r["concept_id"], "subject": r["subject"],
            "taught_at_class": r["taught_at_class"], "canonical_name": r["canonical_name"],
            "canonical_norm": _norm(r["canonical_name"]),
            "aliases": aliases, "alias_norms": {_norm(a) for a in aliases},
            "prerequisites": [p for p in _load_list(r["prerequisites"]) if isinstance(p, str)],
            "status": r["status"]})
    return out


def resolve_name_to_concept_ids(concepts: list, subject: str, name: str, max_class=None) -> list:
    """ID-BASED resolution of a bare name/alias string to concept_id(s) — deterministic. A name resolves to
    every concept in the SAME subject (and, when max_class is given, taught at/below that class) whose
    canonical name OR an alias matches after normalisation. 0 => unresolved (honest null); exactly 1 =>
    the reference SHOULD be stored as that id; >1 => ambiguous, which is precisely why a name is not a safe
    reference. This is the resolver to prefer wherever code currently name-matches a concept."""
    nn = _norm(name)
    seen, out = set(), []
    for c in concepts:
        if c["subject"] != subject:
            continue
        if (max_class is not None and c["taught_at_class"] is not None
                and c["taught_at_class"] > max_class):
            continue
        if (nn == c["canonical_norm"] or nn in c["alias_norms"]) and c["concept_id"] not in seen:
            seen.add(c["concept_id"])
            out.append(c["concept_id"])
    return out


def audit_aliases(iconn, status: str = "certified") -> dict:
    """Deterministic, read-only alias / name / prerequisite collision report over the index.

    Reports (all lists are stable-ordered so a re-run is byte-identical):
      * alias_name_collisions      — an alias of one concept equals the canonical name of a DIFFERENT
                                     concept (same-subject collisions are the dangerous ones for name-based
                                     resolution; cross-subject collisions are reported too, as evidence).
      * canonical_as_alias         — a concept's canonical name appears as an alias of another concept.
      * cross_class_recurring_names — the same (subject, name) taught at >1 class: distinct concept_ids by
                                     design, but a namespace note (R5-5 'revisits/deepens' candidates).
      * prereq_{total,resolved,unresolved,ambiguous} — every prerequisite name resolved id-based within its
                                     subject at/below its class; unresolved (0 targets) + ambiguous (>1).
    """
    concepts = _load_concepts(iconn, status)
    by_id = {c["concept_id"]: c for c in concepts}

    canon_by_subject = {}   # (subject, canonical_norm) -> [concept_id]
    canon_global = {}       # canonical_norm -> [concept_id]
    alias_owner = {}        # alias_norm -> [concept_id]
    name_classes = {}       # (subject, canonical_norm) -> {classes} and [ids]
    for c in concepts:
        canon_by_subject.setdefault((c["subject"], c["canonical_norm"]), []).append(c["concept_id"])
        canon_global.setdefault(c["canonical_norm"], []).append(c["concept_id"])
        for an in c["alias_norms"]:
            alias_owner.setdefault(an, []).append(c["concept_id"])
        nc = name_classes.setdefault((c["subject"], c["canonical_norm"]), {"classes": set(), "ids": []})
        nc["classes"].add(c["taught_at_class"])
        nc["ids"].append(c["concept_id"])

    # 1. alias collides with ANOTHER concept's canonical name
    alias_name_collisions = []
    for c in concepts:
        for a in c["aliases"]:
            an = _norm(a)
            if an == c["canonical_norm"]:
                continue  # alias == own name is harmless
            same_subj = sorted({cid for cid in canon_by_subject.get((c["subject"], an), [])
                                if cid != c["concept_id"]})
            cross_subj = sorted({cid for cid in canon_global.get(an, [])
                                 if cid != c["concept_id"] and by_id[cid]["subject"] != c["subject"]})
            if same_subj or cross_subj:
                alias_name_collisions.append({
                    "concept_id": c["concept_id"], "canonical_name": c["canonical_name"], "alias": a,
                    "collides_same_subject": same_subj, "collides_cross_subject": cross_subj})

    # 2. a canonical name appears as an alias of a DIFFERENT concept
    canonical_as_alias = []
    for c in concepts:
        owners = sorted({cid for cid in alias_owner.get(c["canonical_norm"], []) if cid != c["concept_id"]})
        if owners:
            canonical_as_alias.append({"concept_id": c["concept_id"],
                                       "canonical_name": c["canonical_name"], "aliased_by": owners})

    # 3. same (subject, name) taught at more than one class — distinct ids by design; a namespace note
    cross_class_recurring_names = []
    for (subj, cn), nc in name_classes.items():
        if len(nc["classes"]) > 1:
            cross_class_recurring_names.append({
                "subject": subj, "canonical_name": cn,
                "classes": sorted(x for x in nc["classes"] if x is not None),
                "concept_ids": sorted(set(nc["ids"]))})

    # 4. prerequisite resolution (id-based) — the 53-95 ambiguous / unresolved refs
    prereq_total = prereq_resolved = 0
    prereq_unresolved, prereq_ambiguous = [], []
    for c in concepts:
        for p in c["prerequisites"]:
            prereq_total += 1
            ids = resolve_name_to_concept_ids(concepts, c["subject"], p, max_class=c["taught_at_class"])
            if len(ids) == 1:
                prereq_resolved += 1
            elif not ids:
                prereq_unresolved.append({"concept_id": c["concept_id"], "prerequisite": p})
            else:
                prereq_ambiguous.append({"concept_id": c["concept_id"], "prerequisite": p, "targets": ids})

    return {
        "status_scope": status, "concepts_audited": len(concepts),
        "alias_name_collisions": alias_name_collisions,
        "canonical_as_alias": canonical_as_alias,
        "cross_class_recurring_names": cross_class_recurring_names,
        "prereq_total": prereq_total, "prereq_resolved": prereq_resolved,
        "prereq_unresolved": prereq_unresolved, "prereq_ambiguous": prereq_ambiguous,
    }


def audit(index_path: str = None, status: str = "certified") -> dict:
    ip = str(index_path or (config.KIE_HOME / "knowledge_index.db"))
    iconn = sqlite3.connect(f"file:{ip}?mode=ro", uri=True)
    iconn.row_factory = sqlite3.Row
    try:
        return audit_aliases(iconn, status)
    finally:
        iconn.close()


def main(argv) -> int:
    status = "certified"
    args = []
    it = iter(argv)
    for a in it:
        if a == "--status":
            status = next(it)
        else:
            args.append(a)
    rep = audit(args[0] if args else None, status)
    print(f"ALIAS AUDIT [{rep['status_scope']}]: concepts={rep['concepts_audited']} "
          f"alias_name_collisions={len(rep['alias_name_collisions'])} "
          f"canonical_as_alias={len(rep['canonical_as_alias'])} "
          f"cross_class_names={len(rep['cross_class_recurring_names'])}")
    print(f"  prereqs: total={rep['prereq_total']} resolved={rep['prereq_resolved']} "
          f"unresolved={len(rep['prereq_unresolved'])} ambiguous={len(rep['prereq_ambiguous'])}")
    for x in rep["alias_name_collisions"][:25]:
        print(f"  [alias/name] {x['concept_id']} alias={x['alias']!r} "
              f"same_subj={x['collides_same_subject']} cross_subj={x['collides_cross_subject']}")
    for x in rep["prereq_ambiguous"][:25]:
        print(f"  [ambiguous prereq] {x['concept_id']} {x['prerequisite']!r} -> {x['targets']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
