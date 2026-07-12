"""Governed Biology concept/entity resolution (Phase B10) — precise, specificity-gated.

The B7 strict answer-title resolver had LOW RECALL (mapped ~103/2283 Biology items) because it only fires when
the CORRECT-ANSWER text equals a concept title (e.g. "mitochondrion"→BIO_MITOCHONDRIA). Most NEET Biology
questions name their concept in the STEM via a specific biological entity ("Which hormone raises blood
glucose?" → glucagon → endocrine), not in the answer, so their abundant, DIVERSE evidence stayed in coarse
`Biology:cell`/`:hormone` buckets and could never be verified.

This resolver links an item to an EXISTING canonical concept using a CURATED lexicon of SPECIFIC, unambiguous
biological entities (nephron, glomerulus, glucagon, seminiferous, chlorophyll, ...), each mapped to ONE
canonical concept_code. It deliberately excludes generic tokens ("plant", "system", "hormone", "cell" alone)
that caused a naive token-overlap resolver to force noisy stems into the wrong concept
("plant growth regulator" → wastewater treatment). It fires only when a specific entity is present AND there
is a clear winning concept; on ambiguity or absence it returns None (never forced). Maps ONLY to concepts that
already exist and are active. Deterministic, stdlib-only, read-only.

Scope guard: every target concept_code below is asserted to exist+active at build time; unknown codes are
dropped with a recorded warning rather than silently inventing a concept.
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, List, Optional, Set, Tuple

# ── curated specific-entity lexicon: canonical concept_code -> unambiguous entity terms ───────────────
# Each term is specific enough that its presence strongly implies THIS concept. Generic words are excluded.
# Terms are matched as whole words (word-boundary) against normalized stem+answer text.
_LEXICON: Dict[str, Tuple[str, ...]] = {
    "BIO_HUMAN_ENDOCRINE_SYSTEM": (
        "glucagon", "insulin", "thyroxine", "parathormone", "adrenaline", "aldosterone", "oxytocin",
        "prolactin", "cortisol", "calcitonin", "thymosin", "gonadotropin", "vasopressin", "pituitary",
        "hypothalamus", "adrenal", "thyroid", "pancreas islets", "melatonin", "glucocorticoid"),
    "BIO_CIRCULATORY_SYSTEM": (
        "erythrocyte", "haemoglobin", "hemoglobin", "systole", "diastole", "ventricle", "atrium", "aorta",
        "pacemaker", "sinoatrial", "purkinje", "vena cava", "pulmonary artery", "myogenic", "lymph",
        "leucocyte", "thrombocyte", "erythropoiesis"),
    "BIO_HUMAN_REPRODUCTION": (
        "seminiferous", "spermatogenesis", "oogenesis", "ovulation", "endometrium", "acrosome",
        "gametogenesis", "blastocyst", "trophoblast", "corpus luteum", "graafian", "spermatid",
        "capacitation", "parturition", "lactation", "menstrual", "zygote"),
    "BIO_CELL_STRUCTURE_AND_FUNCTIONS": (
        "golgi", "lysosome", "endoplasmic reticulum", "centriole", "nucleolus", "peroxisome", "ribosome",
        "cytoskeleton", "plasmodesmata", "tonoplast", "glyoxysome"),
    "BIO_MITOCHONDRIA": ("mitochondria", "mitochondrion", "cristae", "oxysome", "f1 particle"),
    "BIO_PHOTOSYNTHESIS_FOODMAKING_PROCES": (
        "chlorophyll", "chloroplast", "calvin cycle", "photolysis", "grana", "thylakoid", "photosystem",
        "rubisco", "stroma", "photophosphorylation", "carotenoid"),
    "BIO_RESPIRATION_THE_ENERGY_RELEASING": (
        "glycolysis", "krebs cycle", "pyruvate", "acetyl coa", "electron transport chain", "oxidative phosphor",
        "citric acid cycle", "fermentation", "glucose oxidation"),
    "BIO_EXCRETORY_SYSTEM_IN_HUMANS": (
        "nephron", "glomerulus", "bowman", "ureter", "urethra", "malpighian", "henle", "micturition",
        "uriniferous", "podocyte", "juxtaglomerular", "ultrafiltration"),
    "BIO_NEURAL_CONTROL_ANDCOORDINATION": (
        "neuron", "axon", "synapse", "myelin", "neurotransmitter", "dendrite", "cerebellum", "medulla",
        "nerve impulse", "saltatory", "acetylcholine", "ranvier", "meninges"),
    "BIO_MOLECULAR_BASIS_OFINHERITANCE": (
        "okazaki", "transcription", "translation", "codon", "anticodon", "helicase", "polymerase",
        "semiconservative", "lac operon", "nucleosome", "spliceosome", "template strand"),
    "BIO_GENETIC_DISORDERS": (
        "klinefelter", "turner syndrome", "haemophilia", "thalassemia", "down syndrome", "colour blindness",
        "sickle cell", "phenylketonuria", "trisomy"),
    "BIO_DIGESTION_IN_HUMANS": (
        "pepsin", "trypsin", "villi", "peristalsis", "chymotrypsin", "enterokinase", "hepatopancreatic",
        "gastric juice", "bile salt"),
    "BIO_IMMUNITY": (
        "antibody", "antigen", "lymphocyte", "immunoglobulin", "macrophage", "interferon", "antitoxin",
        "b cell", "t cell", "humoral", "cytokine"),
    "BIO_HUMAN_RESPIRATORY_SYSTEM": (
        "alveoli", "bronchi", "trachea", "diaphragm", "tidal volume", "residual volume", "bronchiole",
        "pleural", "haldane", "bohr effect", "spirometry"),
}

_WORD = re.compile(r"[a-z][a-z ]+")


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z ]+", " ", (s or "").lower())).strip()


def validate_lexicon(kconn: sqlite3.Connection) -> Tuple[Dict[str, Tuple[str, ...]], List[str]]:
    """Keep only lexicon entries whose concept_code exists+active in kie.db; return (kept, dropped_codes)."""
    active = {r[0] for r in kconn.execute(
        "SELECT concept_code FROM concepts WHERE status='active' AND subject_domain='Biology'")}
    kept, dropped = {}, []
    for code, terms in _LEXICON.items():
        (kept.__setitem__(code, terms) if code in active else dropped.append(code))
    return kept, dropped


class BioResolver:
    def __init__(self, lexicon: Dict[str, Tuple[str, ...]]):
        # term -> concept_code (a term maps to exactly one concept; drop any accidental cross-concept dup)
        term_owner: Dict[str, str] = {}
        dup: Set[str] = set()
        for code, terms in lexicon.items():
            for t in terms:
                if t in term_owner and term_owner[t] != code:
                    dup.add(t)
                term_owner[t] = code
        for t in dup:
            term_owner.pop(t, None)
        self._terms = term_owner
        # longest terms first so multiword entities match before any substring token
        self._ordered = sorted(term_owner, key=len, reverse=True)

    def resolve(self, stem: str, answer: str = "", subject: str = "Biology") -> Optional[str]:
        if subject and subject != "Biology":
            return None
        text = " " + _norm(f"{stem} {answer}") + " "
        hits: Dict[str, int] = {}
        for term in self._ordered:
            if f" {term} " in text or (" " + term + " ") in text:
                hits[self._terms[term]] = hits.get(self._terms[term], 0) + 1
        if not hits:
            return None
        ranked = sorted(hits.items(), key=lambda kv: -kv[1])
        # require a clear winner: top strictly greater than runner-up (no ambiguous ties)
        if len(ranked) >= 2 and ranked[0][1] == ranked[1][1]:
            return None
        return ranked[0][0]


def build_resolver(kconn: sqlite3.Connection):
    """Return a callable(stem, answer, subject)->concept_code|None over the validated lexicon."""
    lex, dropped = validate_lexicon(kconn)
    r = BioResolver(lex)
    fn = lambda stem, answer, subject="Biology": r.resolve(stem, answer, subject)
    fn.dropped_codes = dropped  # type: ignore[attr-defined]
    fn.n_terms = len(r._terms)  # type: ignore[attr-defined]
    return fn


def build_combined_resolver(kconn: sqlite3.Connection):
    """Governed combined concept resolver for the miner/KVS/Tier-2 pipeline: for BIOLOGY, try the specific-
    entity resolver (this module) first, then fall back to the B7 strict answer-title resolver; for every
    OTHER subject use the strict resolver ALONE, so Physics/Chemistry/Mathematics resolution stays byte-
    identical (frozen). Signature: (stem, answer, subject) -> concept_code | None."""
    from kie.qie import concept_resolve
    strict = concept_resolve.build_resolver(kconn)
    bio = build_resolver(kconn)

    def _resolve(stem, answer, subject):
        if subject == "Biology":
            return bio(stem, answer, subject) or strict(stem, answer, subject)
        return strict(stem, answer, subject)
    return _resolve
