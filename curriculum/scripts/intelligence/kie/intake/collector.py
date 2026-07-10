"""Input collector — normalizes every supported Intake input into a flat list of
local files (`IntakeSource`). This is the single funnel for:

    Single PDF · Multiple PDFs · Folder Import · ZIP Import · Drag & Drop · Watch Folder

and a *placeholder* for Direct URL Import (no online downloading — raises).

Pure path/hash resolution only: no DB writes, no verification, no copying. Determinism —
results are always sorted by resolved path so a batch is reproducible.
"""
from __future__ import annotations

import hashlib
import shutil
import tempfile
import zipfile
from pathlib import Path
from typing import Iterable, List, Optional

from kie.intake.models import IntakeSource

# Loose documents the pipeline can ingest directly.
DOC_EXTS = {".pdf"}
# Single-document archives (DIKSHA .ecar etc.) → ingested whole by phase2 parse_archive.
ARCHIVE_DOC_EXTS = {".ecar"}
# Container archives → EXPANDED; each member PDF becomes its own resource.
CONTAINER_EXTS = {".zip"}
SUPPORTED_EXTS = DOC_EXTS | ARCHIVE_DOC_EXTS | CONTAINER_EXTS


class UrlImportNotImplemented(NotImplementedError):
    """Direct URL Import is a declared future extension — offline-only for now."""


def sha256_file(path: Path, _buf: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for block in iter(lambda: fh.read(_buf), b""):
            h.update(block)
    return h.hexdigest()


def _is_supported_file(p: Path) -> bool:
    return p.is_file() and not p.name.startswith(".") and p.suffix.lower() in SUPPORTED_EXTS


def _safe_extract_members(zf: zipfile.ZipFile, dest: Path) -> List[Path]:
    """Extract only regular member files under dest, blocking zip-slip / absolute paths."""
    out: List[Path] = []
    dest = dest.resolve()
    for info in zf.infolist():
        if info.is_dir():
            continue
        name = Path(info.filename)
        if name.is_absolute() or ".." in name.parts:
            continue  # zip-slip guard
        target = (dest / name).resolve()
        if not str(target).startswith(str(dest)):
            continue  # escapes dest → skip
        target.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(info) as src, target.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        out.append(target)
    return out


def expand_zip(zip_path: Path, dest_dir: Path) -> List[Path]:
    """Expand a container zip into dest_dir; return member document paths (sorted)."""
    dest_dir = Path(dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(str(zip_path)) as zf:
        members = _safe_extract_members(zf, dest_dir)
    docs = [m for m in members if m.suffix.lower() in (DOC_EXTS | ARCHIVE_DOC_EXTS)]
    return sorted(docs)


def walk_folder(folder: Path) -> List[Path]:
    """All supported files under a folder, recursively (sorted, dotfiles skipped)."""
    return sorted(p for p in Path(folder).rglob("*") if _is_supported_file(p))


def collect_paths(
    paths: Iterable[Path | str],
    category: Optional[str] = None,
    expand_zips: bool = True,
    _scratch: Optional[Path] = None,
) -> List[IntakeSource]:
    """Resolve arbitrary input paths (files, folders, zips) into IntakeSource records.

    Unifies Single / Multiple / Folder / Drag & Drop. `expand_zips=True` treats a .zip
    as a CONTAINER (its member PDFs become individual resources); .ecar stays a single
    archive document. `category` is a coarse hint; Phase-3 metadata refines from content.
    """
    scratch = Path(_scratch) if _scratch else Path(tempfile.mkdtemp(prefix="kie_intake_zip_"))
    sources: List[IntakeSource] = []
    seen: set[str] = set()

    def _emit(file_path: Path, cat: Optional[str]) -> None:
        rp = str(Path(file_path).resolve())
        if rp in seen:
            return
        seen.add(rp)
        sources.append(IntakeSource(
            original_name=Path(file_path).name,
            origin_path=rp,
            category=cat or category or "Intake",
        ))

    for raw in paths:
        p = Path(raw)
        if not p.exists():
            continue
        if p.is_dir():
            for f in walk_folder(p):
                if f.suffix.lower() in CONTAINER_EXTS and expand_zips:
                    for m in expand_zip(f, scratch / f.stem):
                        _emit(m, category or p.name)
                else:
                    _emit(f, category or p.name)
            continue
        ext = p.suffix.lower()
        if ext in CONTAINER_EXTS and expand_zips:
            for m in expand_zip(p, scratch / p.stem):
                _emit(m, category or p.stem)
        elif ext in SUPPORTED_EXTS:
            _emit(p, category)
        # unsupported files are silently ignored (not intake input)

    # stable, reproducible ordering
    return sorted(sources, key=lambda s: s.origin_path)


def scan_watch_folder(known: dict[str, str], folder: Path, category: Optional[str] = None
                      ) -> tuple[List[IntakeSource], dict[str, str]]:
    """Diff a watch folder against previously seen content hashes.

    `known` maps rel_path -> sha256 (from watch_state). Returns (new_or_changed sources,
    current_index rel_path->sha256). A file is emitted when it is new OR its content hash
    changed (modified file). Deterministic; performs no DB writes.
    """
    folder = Path(folder)
    current: dict[str, str] = {}
    out: List[IntakeSource] = []
    for f in walk_folder(folder):
        rel = str(f.relative_to(folder))
        sha = sha256_file(f)
        current[rel] = sha
        if known.get(rel) != sha:  # new file or content changed
            out.append(IntakeSource(original_name=f.name, origin_path=str(f.resolve()),
                                    category=category or "Watch"))
    return sorted(out, key=lambda s: s.origin_path), current


def url_import(url: str) -> IntakeSource:  # pragma: no cover - intentional stub
    """Placeholder for Direct URL Import. Online downloading is NOT implemented.

    Download the resource locally through an authorized channel, then import the file.
    """
    raise UrlImportNotImplemented(
        "Direct URL Import is a declared future extension; the Intake Center does not "
        "download from the network. Save the file locally and import it as a file."
    )
