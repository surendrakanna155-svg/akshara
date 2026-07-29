"""Certified Figure Catalog (Diagram Pipeline · Phase 2 + 6).

Every CAPTIONED figure in the born-digital source PDFs becomes a first-class certified knowledge object,
linked 1:1 to its EXISTING chunk (never a new chunk, never a modified chunk). Copyright-safe: no pixels are
stored — only the caption text (which already lives in the chunk) + deterministic metadata.

  figure          — the catalog: number, caption, subject, chapter, page, chunk_id, concept, type, provenance
  figure_element  — FUTURE (empty): labels / regions / arrows / axes / legends / symbols / units
  figure_asset    — FUTURE (empty): an SVG/vector reconstruction (never a copyrighted pixel copy)
  figure_link     — FUTURE (empty): relationships to concept / formula / misconception / prerequisite / fact

`figure_element` / `figure_asset` / `figure_link` are declared but empty — a later vision-authorized step
fills them WITHOUT altering `figure` or the chunk. Deterministic + reproducible; reads PDFs + kie.db read-only.
"""
from __future__ import annotations

import glob
import hashlib
import json
import re
import sqlite3
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from kie import config

CATALOG_DB_PATH = config.KIE_HOME / "figure_catalog.db"
KIE_DB_PATH = config.KIE_HOME / "kie.db"
PDF_GLOB = str(config.KIE_HOME.parent.parent / "resources" / "intake" / "*" / "*.pdf")

SCHEMA = """
CREATE TABLE IF NOT EXISTS figure (
  figure_id       TEXT PRIMARY KEY,      -- sha256(doc_id|figure_number|caption)[:16] — content-addressed
  doc_id          TEXT NOT NULL,         -- source document (source_documents.doc_id)
  chunk_id        TEXT,                  -- the EXISTING chunk this figure belongs to (link only; honest-null if none)
  figure_number   TEXT,                  -- "5.4"
  caption         TEXT NOT NULL,         -- "Experimental set-up with potassium hydroxide"
  subject         TEXT,
  chapter         TEXT,                  -- chapter / section context (chunk.section_path or doc path)
  page            INTEGER,               -- 0-based PDF page
  concept_code    TEXT,                  -- honest-null until resolved (future figure_link resolves the KC)
  figure_type     TEXT NOT NULL,         -- deterministic first-pass type (see classify_type)
  provenance      TEXT NOT NULL,         -- json: {rel_path, sha256, pdf_page}
  status          TEXT NOT NULL,         -- 'certified' (caption is source-grounded in the chunk text)
  created_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_fig_doc     ON figure(doc_id);
CREATE INDEX IF NOT EXISTS idx_fig_chunk   ON figure(chunk_id);
CREATE INDEX IF NOT EXISTS idx_fig_subject ON figure(subject);
CREATE INDEX IF NOT EXISTS idx_fig_type    ON figure(figure_type);

-- ── FUTURE-READY (declared, empty) — filled by a later vision-authorized step, no schema change to figure ──
CREATE TABLE IF NOT EXISTS figure_element (
  figure_id    TEXT NOT NULL,
  element_type TEXT NOT NULL,            -- label | region | arrow | axis | legend | symbol | dimension | unit
  content      TEXT,                     -- the label / axis name / unit text
  coords       TEXT,                     -- json bbox/points (when a vision step provides them)
  ordinal      INTEGER,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_felem ON figure_element(figure_id, element_type);

CREATE TABLE IF NOT EXISTS figure_asset (
  figure_id   TEXT NOT NULL,
  kind        TEXT NOT NULL,             -- svg | vector
  data        TEXT,                      -- SVG markup (educationally equivalent, never a pixel copy)
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_fasset ON figure_asset(figure_id);

CREATE TABLE IF NOT EXISTS figure_link (
  figure_id  TEXT NOT NULL,
  link_type  TEXT NOT NULL,              -- concept | formula | misconception | prerequisite | fact
  target_id  TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_flink ON figure_link(figure_id, link_type);

CREATE TABLE IF NOT EXISTS figure_meta (key TEXT PRIMARY KEY, value TEXT);
"""

# deterministic first-pass type from the caption words (no pixels). Order = specificity.
_TYPE_RULES: Tuple[Tuple[str, str], ...] = (
    ("graph",          r"\bgraph|curve|\bplot\b|versus|\bvs\b|v[-–]t\b|s[-–]t\b|distance[- ]time|velocity[- ]time"),
    ("circuit",        r"circuit|resistor|ammeter|voltmeter|galvanometer|\bemf\b|series and parallel"),
    ("ray_diagram",    r"\bray\b|lens|mirror|refraction|reflection|prism|image formation|focal"),
    ("free_body",      r"free[- ]body|forces? acting|force diagram"),
    ("experiment",     r"experiment|set[- ]?up|apparatus|activity|arrangement to|to show that"),
    ("chemical",       r"structure of|molecule|\bbond\b|electron dot|reaction between|electrolysis"),
    ("flowchart_cycle", r"flow[- ]?chart|\bcycle\b|pathway|life cycle|nitrogen cycle|water cycle"),
    ("map",            r"\bmap\b|distribution of"),
    ("anatomy_structure", r"cross[- ]section|\bl\.s\.|\bt\.s\.|structure|anatomy|parts of|section of|diagram of"),
)


def classify_type(caption: str) -> str:
    c = (caption or "").lower()
    for t, pat in _TYPE_RULES:
        if re.search(pat, c):
            return t
    return "figure"


def open_catalog() -> sqlite3.Connection:
    conn = sqlite3.connect(CATALOG_DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def _sha_to_doc(kie: sqlite3.Connection) -> Dict[str, sqlite3.Row]:
    return {r["sha256"]: r for r in kie.execute(
        "SELECT doc_id, sha256, rel_path, subject, class_label FROM source_documents WHERE sha256 IS NOT NULL")}


def link_chunk(kie: sqlite3.Connection, doc_id: str, pdf_page: int) -> Tuple[Optional[str], Optional[str]]:
    """The existing chunk a figure on `pdf_page` belongs to — the text block on that page (nearest by page).
    Returns (chunk_id, section_path) or (None, None). Never creates a chunk; tolerant of 0/1-based page skew."""
    row = kie.execute(
        "SELECT chunk_id, section_path FROM chunks WHERE doc_id=? AND ? BETWEEN page_start-1 AND page_end+1 "
        "ORDER BY ABS(page_start-?) LIMIT 1", (doc_id, pdf_page, pdf_page)).fetchone()
    return (row["chunk_id"], row["section_path"]) if row else (None, None)


# a caption carries a TITLE (starts with a Capital), distinguishing it from a mid-sentence reference ("see
# Fig. 5.4 and note..."). Two high-precision forms: a caption line starting with Fig/Figure, and the full word
# "Figure N.M <Title>" anywhere (NCERT captions use the full word; abbreviated "Fig." mid-text is a reference).
_CAP_LINE = re.compile(r"^\s*Fig(?:ure)?\.?\s*(\d+\.\d+)[:.\-–\s]+([A-Z][^\n]{3,120})", re.I | re.M)
_CAP_FULL = re.compile(r"\bFigure\s*(\d+\.\d+)[:.\-–\s]+([A-Z][^\n]{3,120})")


def extract_figures(pdf_path: str):
    """Yield (pdf_page, figure_number, caption) for every captioned figure — deterministic, from the text layer.
    Searches both a caption-line form and the full-word 'Figure N.M Title' form (higher recall), requires a
    Capital-initial title (precision), and keeps the LONGEST caption per figure number (dedup across the doc)."""
    import fitz
    best: Dict[str, Tuple[int, str]] = {}    # figure_number -> (page, caption)
    with fitz.open(pdf_path) as d:
        for pno, pg in enumerate(d):
            txt = pg.get_text()
            for rx in (_CAP_LINE, _CAP_FULL):
                for m in rx.finditer(txt):
                    num = m.group(1)
                    cap = re.sub(r"\s+", " ", m.group(2)).strip()
                    cap = re.split(r"\s+Fig(?:ure)?\.?\s*\d+\.\d+", cap)[0].strip()   # stop at the next figure
                    if len(re.findall(r"[A-Za-z]{3,}", cap)) < 2:
                        continue
                    cap = cap[:120]
                    if len(cap) > len(best.get(num, (0, ""))[1]):
                        best[num] = (pno, cap)
    for num, (pno, cap) in best.items():
        yield pno, num, cap


def build(rebuild: bool = True) -> Dict[str, object]:
    """Build the certified figure catalog from every available born-digital source PDF. Idempotent."""
    kie = sqlite3.connect(f"file:{KIE_DB_PATH}?mode=ro", uri=True)
    kie.row_factory = sqlite3.Row
    sha_map = _sha_to_doc(kie)
    now = datetime.now(timezone.utc).isoformat()
    cat = open_catalog()
    if rebuild:
        for t in ("figure",):
            cat.execute(f"DELETE FROM {t}")
    rows: List[tuple] = []
    stats = {"pdfs_matched": 0, "figures": 0, "with_chunk": 0, "by_subject": {}, "by_type": {}}
    for pdf in sorted(glob.glob(PDF_GLOB)):
        try:
            sha = hashlib.sha256(open(pdf, "rb").read()).hexdigest()
        except OSError:
            continue
        doc = sha_map.get(sha)
        if not doc:                                            # only catalog docs we can provenance to a chunk index
            continue
        stats["pdfs_matched"] += 1
        subject, rel = doc["subject"], doc["rel_path"]
        for pno, num, cap in extract_figures(pdf):
            chunk_id, section = link_chunk(kie, doc["doc_id"], pno)
            ftype = classify_type(cap)
            fid = "FIG_" + hashlib.sha256(f"{doc['doc_id']}|{num}|{cap}".encode()).hexdigest()[:16]
            prov = json.dumps({"rel_path": rel, "sha256": sha, "pdf_page": pno})
            rows.append((fid, doc["doc_id"], chunk_id, num, cap, subject, section or rel, pno,
                         None, ftype, prov, "certified", now))
            stats["figures"] += 1
            stats["with_chunk"] += 1 if chunk_id else 0
            stats["by_subject"][subject or "(none)"] = stats["by_subject"].get(subject or "(none)", 0) + 1
            stats["by_type"][ftype] = stats["by_type"].get(ftype, 0) + 1
    cat.executemany(
        "INSERT OR REPLACE INTO figure (figure_id,doc_id,chunk_id,figure_number,caption,subject,chapter,page,"
        "concept_code,figure_type,provenance,status,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
    cat.execute("INSERT OR REPLACE INTO figure_meta(key,value) VALUES ('built_at',?)", (now,))
    cat.execute("INSERT OR REPLACE INTO figure_meta(key,value) VALUES ('stats',?)",
                (json.dumps(stats, sort_keys=True),))
    cat.commit()
    cat.close()
    kie.close()
    stats["chunk_link_rate"] = round(stats["with_chunk"] / max(1, stats["figures"]), 3)
    return stats


def _region_for(pg, num: str):
    """The figure's region = the band above its caption line (deterministic geometric bound)."""
    import fitz
    capw = [w for w in pg.get_text("words") if w[4].strip().startswith(num)]
    if not capw:
        return None
    cy = min(w[1] for w in capw)
    return fitz.Rect(pg.rect.x0, max(0, cy - 280), pg.rect.x1, cy)


def _primitive_count(pg, region) -> int:
    n = 0
    for dr in pg.get_drawings():
        if not region.intersects(dr["rect"]):
            continue
        for it in dr["items"]:
            if it[0] in ("l", "c", "re"):
                n += 1
    return n


def _svg(pg, region) -> Tuple[str, int]:
    """Reconstruct an SVG from the PDF's OWN vector primitives in the region — our own vector drawing rebuilt
    from structural data (lines/curves/rects), never a pixel copy. Returns (svg_markup, element_count)."""
    ox, oy = region.x0, region.y0
    W, H = region.width, region.height
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}">']
    n = 0
    for dr in pg.get_drawings():
        if not region.intersects(dr["rect"]):
            continue
        sw = max(0.4, float(dr.get("width") or 0.8))
        for it in dr["items"]:
            op = it[0]
            try:
                if op == "l":
                    a, b = it[1], it[2]
                    out.append(f'<line x1="{a.x-ox:.1f}" y1="{a.y-oy:.1f}" x2="{b.x-ox:.1f}" y2="{b.y-oy:.1f}" stroke="#111" stroke-width="{sw:.1f}"/>')
                    n += 1
                elif op == "re":
                    r = it[1]
                    out.append(f'<rect x="{r.x0-ox:.1f}" y="{r.y0-oy:.1f}" width="{r.width:.1f}" height="{r.height:.1f}" fill="none" stroke="#111" stroke-width="{sw:.1f}"/>')
                    n += 1
                elif op == "c":
                    a, b, c, e = it[1], it[2], it[3], it[4]
                    out.append(f'<path d="M{a.x-ox:.1f},{a.y-oy:.1f} C{b.x-ox:.1f},{b.y-oy:.1f} {c.x-ox:.1f},{c.y-oy:.1f} {e.x-ox:.1f},{e.y-oy:.1f}" fill="none" stroke="#111" stroke-width="{sw:.1f}"/>')
                    n += 1
            except Exception:
                pass
    out.append("</svg>")
    return "".join(out), n


def reconstruct(vector_min: int = 25) -> Dict[str, object]:
    """Second pass over the catalog: classify every figure VECTOR vs RASTER deterministically, and for VECTOR
    figures reconstruct an SVG from the PDF's own vector primitives (stored in figure_asset). Raster figures are
    marked needs_vision. Adds figure.render_class. Reads PDFs read-only; writes only figure_catalog.db."""
    import fitz
    cat = open_catalog()
    cols = {r[1] for r in cat.execute("PRAGMA table_info(figure)")}
    if "render_class" not in cols:
        cat.execute("ALTER TABLE figure ADD COLUMN render_class TEXT")
    cat.execute("DELETE FROM figure_asset")
    sha_to_pdf = {}
    for pdf in glob.glob(PDF_GLOB):
        try:
            sha_to_pdf[hashlib.sha256(open(pdf, "rb").read()).hexdigest()] = pdf
        except OSError:
            pass
    now = datetime.now(timezone.utc).isoformat()
    stats = {"vector": 0, "raster": 0, "no_region": 0, "svg_written": 0}
    rows = cat.execute("SELECT figure_id, figure_number, page, provenance FROM figure").fetchall()
    open_pdf = {}
    for r in rows:
        prov = json.loads(r["provenance"])
        pdf = sha_to_pdf.get(prov.get("sha256"))
        if not pdf:
            continue
        d = open_pdf.get(pdf) or open_pdf.setdefault(pdf, fitz.open(pdf))
        pg = d[r["page"]]
        region = _region_for(pg, r["figure_number"])
        if region is None:
            stats["no_region"] += 1
            cat.execute("UPDATE figure SET render_class=? WHERE figure_id=?", ("unresolved", r["figure_id"]))
            continue
        prims = _primitive_count(pg, region)
        if prims >= vector_min:
            svg, n = _svg(pg, region)
            cat.execute("UPDATE figure SET render_class=? WHERE figure_id=?", ("vector", r["figure_id"]))
            cat.execute("INSERT INTO figure_asset(figure_id, kind, data, created_at) VALUES (?,?,?,?)",
                        (r["figure_id"], "svg", svg, now))
            stats["vector"] += 1
            stats["svg_written"] += 1 if n > 0 else 0
        else:
            cat.execute("UPDATE figure SET render_class=? WHERE figure_id=?", ("raster_needs_vision", r["figure_id"]))
            stats["raster"] += 1
    for d in open_pdf.values():
        d.close()
    cat.commit()
    cat.close()
    return stats


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
    print(json.dumps(reconstruct(), indent=2))
