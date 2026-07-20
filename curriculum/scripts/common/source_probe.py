"""Lightweight URL probe — inspect before queue (no blind downloads).

HEAD (or a tiny Range GET) to confirm content-type and PDF/ZIP magic bytes.
Used by discovery catalogues so only confirmed endpoints enter DOWNLOAD_QUEUE.json.
"""

from __future__ import annotations

import urllib.error
import urllib.request

_PDF = b"%PDF"
_ZIP = b"PK\x03\x04"


def probe_url(
    url: str,
    opener: urllib.request.OpenerDirector | None = None,
    *,
    timeout: float = 15.0,
    referer: str | None = None,
    user_agent: str = "AksharaCurriculumBot/1.0 (+education-repository)",
) -> dict:
    """Return {ok, content_type, content_length, reason}. Never raises."""
    headers = {"User-Agent": user_agent}
    if referer:
        headers["Referer"] = referer
    op = opener or urllib.request.build_opener()
    req = urllib.request.Request(url, headers=headers, method="HEAD")
    try:
        with op.open(req, timeout=timeout) as resp:
            ctype = (resp.headers.get("Content-Type") or "").lower()
            clen = resp.headers.get("Content-Length")
            length = int(clen) if clen and clen.isdigit() else None
            if "pdf" in ctype or "zip" in ctype:
                return {"ok": True, "content_type": ctype, "content_length": length, "reason": "HEAD"}
            if "html" in ctype:
                return {"ok": False, "content_type": ctype, "content_length": length, "reason": "HTML_NOT_PDF"}
            # Some servers omit type on HEAD — peek first bytes
    except urllib.error.HTTPError as exc:
        if exc.code not in (405, 501):  # HEAD not supported
            return {"ok": False, "content_type": "", "content_length": None, "reason": f"HTTP_{exc.code}"}
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return {"ok": False, "content_type": "", "content_length": None, "reason": type(exc).__name__}

    # Range GET fallback (first 8 bytes only)
    headers["Range"] = "bytes=0-7"
    req = urllib.request.Request(url, headers=headers)
    try:
        with op.open(req, timeout=timeout) as resp:
            ctype = (resp.headers.get("Content-Type") or "").lower()
            magic = resp.read(8)
            if magic.startswith(_PDF) or magic.startswith(_ZIP):
                clen = resp.headers.get("Content-Length")
                return {"ok": True, "content_type": ctype, "content_length": int(clen) if clen and clen.isdigit() else None, "reason": "RANGE_MAGIC"}
            return {"ok": False, "content_type": ctype, "content_length": None, "reason": "BAD_MAGIC"}
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return {"ok": False, "content_type": "", "content_length": None, "reason": type(exc).__name__}
