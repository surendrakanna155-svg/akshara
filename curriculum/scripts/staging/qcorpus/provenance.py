"""Source provenance loader.

Each download group ships a manifest.json (produced by the acquisition/download tooling)
carrying per-file source identity: subject, chapter, section, the original topic_url and the
original pdf_url. This is gold-standard provenance and we PRESERVE it verbatim, then use it
as HIGH-CONFIDENCE evidence for subject/chapter classification. We never fabricate provenance;
files absent from a manifest simply carry no source_url and lower classification confidence.
"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Optional

from qcorpus import config


@lru_cache(maxsize=None)
def _group_manifest(group: str) -> dict:
    """Map: file-basename(lower) -> provenance record, for one source group."""
    mpath = config.SOURCE_ROOT / group / "manifest.json"
    if not mpath.exists():
        return {}
    try:
        raw = json.loads(mpath.read_text(encoding="utf-8"))
    except Exception:
        return {}
    entries = raw if isinstance(raw, list) else raw.get("files") or raw.get("entries") or []
    out: dict = {}
    for e in entries:
        if not isinstance(e, dict):
            continue
        f = e.get("file") or e.get("path") or e.get("filename")
        if not f:
            continue
        out[Path(f).name.lower()] = {
            "subject": e.get("subject"),
            "chapter": e.get("chapter"),
            "section": e.get("section"),
            "topic": e.get("topic") or e.get("topic_name"),
            "source_url": e.get("pdf_url") or e.get("url"),
            "topic_url": e.get("topic_url"),
        }
    return out


def lookup(group: str, filename: str) -> Optional[dict]:
    """Provenance record for a file within a group, or None if not manifest-tracked."""
    rec = _group_manifest(group).get(Path(filename).name.lower())
    return dict(rec) if rec else None
