"""Shared data-lane utilities for the Curriculum Intelligence acquisition scripts.

Mirrors the idiom of `scripts/verification/` (stdlib-only, config-driven, atomic
JSON writes) and layers the concerns the CI-A* waves share: config loading, path
resolution off configs/paths.json, append-only logging into logs/, checkpoint
save/load, and deterministic resource-ID / repository-filename generation.

Nothing here downloads anything or touches app trees. Import style follows the
existing flat convention (import by filename after a sys.path.insert).
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# curriculum/scripts/common/workspace.py  ->  parents[2] == curriculum/
WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
_VERIFICATION_DIR = Path(__file__).resolve().parents[1] / "verification"


def utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_json(path: Path, default=None):
    path = Path(path)
    if path.exists():
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    return default


def write_json(path: Path, data) -> None:
    """Atomic write (tmp + replace) — same durability contract as the engine."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    tmp.replace(path)


def get_engine(workspace_root: Path):
    """Construct the certified VerificationEngine for `workspace_root`.

    The downloader routes every fetched file through this — direct writes into
    resources/ are prohibited (spec §5).
    """
    if str(_VERIFICATION_DIR) not in sys.path:
        sys.path.insert(0, str(_VERIFICATION_DIR))
    from verification_engine import VerificationEngine  # noqa: E402

    return VerificationEngine(Path(workspace_root))


class Workspace:
    """Config + path resolver rooted at a curriculum/ workspace (real or temp)."""

    def __init__(self, root: Path | None = None):
        self.root = Path(root) if root else WORKSPACE_ROOT
        self.configs_dir = self.root / "configs"
        self._cache: dict[str, dict] = {}
        self.paths = self.config("paths")

    # ---------------------------------------------------------------- configs
    def config(self, name: str) -> dict:
        if name in self._cache:
            return self._cache[name]
        data = load_json(self.configs_dir / f"{name}.json")
        if data is None:
            raise FileNotFoundError(f"missing config: {self.configs_dir / (name + '.json')}")
        self._cache[name] = data
        return data

    # ------------------------------------------------------------ path lookups
    def p(self, key: str) -> Path:
        return self.root / self.paths[key]

    def pm(self, key: str) -> Path:
        return self.root / self.paths["pm_files"][key]

    def index(self, key: str) -> Path:
        return self.p("indexes_dir") / self.paths["index_files"][key]

    def report(self, key: str) -> Path:
        return self.p("reports_dir") / self.paths["report_files"][key]

    def log_path(self, key: str) -> Path:
        return self.p("logs_dir") / self.paths["log_files"][key]

    # -------------------------------------------------------------- json state
    def read(self, path: Path, default=None):
        return load_json(path, default)

    def write(self, path: Path, data) -> None:
        write_json(path, data)

    # ---------------------------------------------------------------- logging
    def log(self, key: str, message: str) -> None:
        """Append-only engineering log (spec Part 04 log dir; never overwrite)."""
        lp = self.log_path(key)
        lp.parent.mkdir(parents=True, exist_ok=True)
        with lp.open("a", encoding="utf-8") as fh:
            fh.write(f"{utcnow()} {message}\n")

    # ------------------------------------------------------------- checkpoints
    def append_session(self, lines: list[str]) -> None:
        sl = self.pm("session_log")
        sl.parent.mkdir(parents=True, exist_ok=True)
        with sl.open("a", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")

    # ---------------------------------------------------- identity / filenames
    def resource_id(self, board_code: str, class_code: str, subject_code: str,
                    category: str, year: str, seq: int) -> str:
        fr = self.config("folder_rules")["resource_id_format"]
        type_code = fr["type_codes"].get(category, "MISC")
        width = fr["seq_width"]
        return f"AKS-{board_code}-{class_code}-{subject_code}-{type_code}-{year}-{seq:0{width}d}"

    def repo_filename(self, board_code: str, class_label: str, subject_folder: str,
                      resource_type: str, year: str, version: str, language: str,
                      ext: str) -> str:
        name = f"{board_code}_{class_label}_{subject_folder}_{resource_type}_{year}_{version}_{language}.{ext}"
        return sanitize_filename(name)


_SPACES = re.compile(r"\s+")
_ILLEGAL = re.compile(r"[^A-Za-z0-9._-]")


def sanitize_filename(name: str) -> str:
    """Enforce the naming standard: no spaces, underscores only, pattern-safe."""
    name = _SPACES.sub("_", name.strip())
    name = _ILLEGAL.sub("_", name)
    return name


def make_sample_pdf(pages: int = 2, pad_to: int = 12000) -> bytes:
    """A tiny but structurally valid PDF (header, objects, xref, %%EOF, startxref).

    Used only for the local dry-run and tests — never a real curriculum resource.
    Padded past the real 10 KB PDF size floor so it passes V4 under production config.
    """
    kids = " ".join(f"{3 + i} 0 R" for i in range(pages))
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{kids}] /Count {pages} >>".encode(),
    ]
    for _ in range(pages):
        objects.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>")

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode() + body + b"\nendobj\n"
    if pad_to and len(out) < pad_to:  # pad inside a comment to reach the size floor
        out += b"%" + b"P" * (pad_to - len(out) - 2) + b"\n"
    xref_pos = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode()
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += (f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n").encode()
    return bytes(out)
