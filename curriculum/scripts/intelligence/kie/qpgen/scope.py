"""Syllabus Scope Resolver — turns a request into the certified, CLEAN, in-scope concept
universe, and refuses anything the KIE cannot back.

Boundary model (grounded in the real data): concepts carry only `subject_domain`, so grade/
exam boundaries come from `source_documents` facets via the concept→doc linkage, and a
concept is admitted only if it is (a) clean (sanitizer) and (b) evidence-backed — it appears
in Question Intelligence, or is a named law/formula, or has a definition. The resolved
`concept_codes` set is the HARD boundary every downstream stage must stay inside.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, FrozenSet, List, Optional

from kie.qpgen import presets, sanitize
from kie.qpgen.models import PaperRequest, Subject


class ScopeError(ValueError):
    """Request maps to an unsupported / unknown scope."""


class ScopeEmptyError(ScopeError):
    """No certified, clean, in-scope concept exists — refuse rather than fabricate."""


@dataclass
class ConceptRef:
    concept_code: str
    title: str
    subject: Optional[str]
    exam: Optional[str]
    evidence: int            # strength: summed pattern frequency (+ baselines)
    is_named_law: bool
    has_definition: bool


@dataclass
class SyllabusScope:
    exam_profile: str
    subjects: List[str]
    concepts: Dict[str, ConceptRef]
    chapters: List[str]
    stats: Dict = field(default_factory=dict)

    @property
    def concept_codes(self) -> FrozenSet[str]:
        return frozenset(self.concepts)

    def in_scope(self, concept_code: str) -> bool:
        return concept_code in self.concepts


def _pattern_frequency(conn) -> Dict[str, int]:
    return {
        r["concept_code"]: r["f"]
        for r in conn.execute(
            "SELECT concept_code, SUM(COALESCE(frequency,0)) f FROM question_patterns "
            "WHERE concept_code IS NOT NULL GROUP BY concept_code"
        ).fetchall()
    }


def _formula_concepts(conn) -> set:
    return {r["concept_code"] for r in conn.execute(
        "SELECT DISTINCT concept_code FROM formulas WHERE concept_code IS NOT NULL").fetchall()}


def resolve_scope(conn, request: PaperRequest) -> SyllabusScope:
    profile = presets.resolve_exam_profile(request.exam, request.board, request.class_label)
    if not profile:
        raise ScopeError(
            f"unsupported scope (exam={request.exam!r} board={request.board!r} "
            f"class={request.class_label!r}); certified profiles: {sorted(presets.EXAM_PROFILES)}")
    pdef = presets.EXAM_PROFILES[profile]
    profile_subjects = set(pdef["subjects"])
    source_exams = set(pdef["source_exams"])

    # subject selection must be within the profile
    if request.subjects:
        requested = set(request.subjects)
        bad = requested - profile_subjects
        if bad:
            raise ScopeError(f"subjects {sorted(bad)} are not in exam profile {profile} "
                             f"(offers {sorted(profile_subjects)})")
        subjects = requested
    else:
        subjects = profile_subjects

    freq = _pattern_frequency(conn)
    formulas = _formula_concepts(conn)
    chapter_terms = [c.strip().lower() for c in (request.chapters or ()) if c.strip()]

    rows = conn.execute(
        "SELECT c.concept_code, c.title, c.subject_domain, c.definition, "
        "       sd.exam AS doc_exam "
        "FROM concepts c "
        "LEFT JOIN source_documents sd ON sd.doc_id = json_extract(c.evidence,'$.doc') "
        "WHERE c.subject_domain IN (%s) AND c.status='active'" % ",".join("?" * len(subjects)),
        tuple(sorted(subjects)),
    ).fetchall()

    concepts: Dict[str, ConceptRef] = {}
    considered = clean_ct = evidence_ct = 0
    for r in rows:
        considered += 1
        title = r["title"]
        if not sanitize.is_clean_concept(title):
            continue
        clean_ct += 1
        code = r["concept_code"]
        f = freq.get(code, 0)
        has_def = bool((r["definition"] or "").strip())
        is_law = code in formulas
        if not (f > 0 or has_def or is_law):
            continue                                   # no exam/definition/law evidence → drop
        evidence_ct += 1
        # exam-provenance boundary: the concept's source doc must be in-profile (NCERT/Practice
        # are in every profile, so textbook-derived concepts pass; cross-exam leakage is cut).
        doc_exam = r["doc_exam"]
        if doc_exam and doc_exam not in source_exams:
            continue
        # chapter filter (optional, strict): title must match a requested chapter term
        if chapter_terms and not any(term in title.lower() for term in chapter_terms):
            continue
        base = 3 if is_law else (2 if has_def else 0)
        concepts[code] = ConceptRef(code, title, r["subject_domain"], doc_exam,
                                    evidence=f + base, is_named_law=is_law, has_definition=has_def)

    if not concepts:
        raise ScopeEmptyError(
            f"no certified clean in-scope concept for profile={profile} subjects={sorted(subjects)}"
            + (f" chapters={chapter_terms}" if chapter_terms else "")
            + " — refusing to fabricate out-of-syllabus content")

    stats = {
        "profile": profile, "subjects": sorted(subjects), "considered": considered,
        "clean": clean_ct, "evidence_backed": evidence_ct, "in_scope": len(concepts),
        "by_subject": _count_by(concepts.values(), lambda c: c.subject),
    }
    return SyllabusScope(profile, sorted(subjects), concepts, chapter_terms, stats)


def _count_by(items, key) -> Dict:
    out: Dict = {}
    for it in items:
        k = key(it)
        out[k] = out.get(k, 0) + 1
    return out
