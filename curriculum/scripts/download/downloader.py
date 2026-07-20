#!/usr/bin/env python3
"""Checkpoint-resumable curriculum downloader (spec Parts 02/03 + engine §5).

Contract (non-negotiable):
  * Every fetched file is routed through the certified VerificationEngine
    (verify_resource → V1-V11). Direct writes into resources/ are prohibited.
  * On any verification failure the engine's recovery ladder decides the next
    move (next_recovery_action → RETRY | TRY_ALTERNATIVE | RECORD_MISSING).
  * Resumable: entries already VERIFIED / NOT_PUBLICLY_AVAILABLE are skipped;
    RETRY_PENDING entries respect their backoff `next_retry` unless overridden.

LEGAL (Risk R1): default mode is dry-run and network is DISABLED
(download_rules.json: default_mode='dry_run', allow_network=false). In this
environment the downloader only "fetches" local `file:` sources (copy into
downloads/incoming) — it builds + wires the full pipeline without acquiring any
copyrighted content. A real networked run flips allow_network=true; the https
fetch path below is where urllib would stream the file (documented, not exercised
here). Entries whose source_url is still null need a networked discovery run first.

Usage:
  downloader.py [--workspace DIR] [--allow-network] [--ignore-backoff] [--limit N]
"""

from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, get_engine, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]

TERMINAL = {"VERIFIED", "NOT_PUBLICLY_AVAILABLE"}


def _order_key(entry: dict, board_seq: dict, class_order: list, cat_order: list) -> tuple:
    b = board_seq.get(entry.get("board", ""), 99)
    c = class_order.index(entry["class_label"]) if entry.get("class_label") in class_order else 99
    cat = entry.get("resource_category", "")
    ci = cat_order.index(cat) if cat in cat_order else 99
    return (b, c, ci, entry.get("resource_id", ""))


_GDRIVE_HOSTS = {"drive.google.com", "drive.usercontent.google.com", "docs.google.com"}


def _fetch_gdrive(file_id: str, dest: Path, net: dict) -> tuple[bool, str]:
    """Download a Google Drive file, handling the large-file confirm interstitial.

    Returns (ok, note). Never raises — any error is a recoverable fetch failure.
    """
    import http.cookiejar  # noqa: E402
    import re  # noqa: E402
    import urllib.request  # noqa: E402

    base = "https://drive.usercontent.google.com/download"
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    headers = {"User-Agent": net["user_agent"]}

    def _open(url):
        return opener.open(urllib.request.Request(url, headers=headers),
                           timeout=net["read_timeout_seconds"])

    try:
        url = f"{base}?id={file_id}&export=download"
        resp = _open(url)
        ctype = (resp.headers.get("Content-Type") or "").lower()
        if "text/html" in ctype:
            # confirm interstitial — extract hidden form fields and re-request
            body = resp.read(200_000).decode("utf-8", "ignore")
            fields = dict(re.findall(r'name="(confirm|uuid|id|export)"\s+value="([^"]*)"', body))
            if not fields.get("confirm"):
                m = re.search(r"confirm=([0-9A-Za-z_-]+)", body)
                if m:
                    fields["confirm"] = m.group(1)
            if not fields.get("confirm"):
                return False, "GDRIVE_NO_CONFIRM_TOKEN (not a downloadable file / access gated)"
            q = f"{base}?id={file_id}&export=download&confirm={fields['confirm']}"
            if fields.get("uuid"):
                q += f"&uuid={fields['uuid']}"
            resp = _open(q)
            ctype = (resp.headers.get("Content-Type") or "").lower()
            if "text/html" in ctype:
                return False, "GDRIVE_STILL_HTML (interstitial not cleared)"
        with dest.open("wb") as fh:
            shutil.copyfileobj(resp, fh, length=net["chunk_bytes"])
        return True, "downloaded via google-drive"
    except Exception as exc:  # noqa: BLE001
        if dest.exists():
            dest.unlink(missing_ok=True)
        return False, f"GDRIVE_ERROR: {type(exc).__name__}: {exc}"


def _fetch(entry: dict, ws: Workspace, rules: dict, allow_network: bool) -> tuple[bool, Path | None, str]:
    """Return (ok, incoming_path, note). Never raises on an expected failure."""
    url = entry.get("source_url")
    incoming = ws.p("downloads_incoming")
    incoming.mkdir(parents=True, exist_ok=True)
    dest = incoming / entry["expected_filename"]

    if not url:
        return False, None, "UNRESOLVED_URL (needs a networked discovery run)"

    scheme = urlparse(url).scheme
    if scheme not in rules["allowed_url_schemes"]:
        return False, None, f"SCHEME_NOT_ALLOWED: {scheme}"

    # Google Drive (owner-authorised non-official TS source) — needs confirm-token flow
    if scheme == "https" and urlparse(url).netloc in _GDRIVE_HOSTS:
        if not allow_network:
            return False, None, "NETWORK_DISABLED (allow_network=false — dry-run scaffolding)"
        fid = entry.get("gdrive_file_id")
        if not fid:
            import re as _re
            m = _re.search(r"[?&]id=([^&]+)", url)
            fid = m.group(1) if m else None
        if not fid:
            return False, None, "GDRIVE_NO_FILE_ID"
        import time as _time
        ok, note = _fetch_gdrive(fid, dest, rules["networking"])
        if ok:
            _time.sleep(rules["networking"].get("polite_delay_seconds", 0))
            return True, dest, note
        return False, None, note

    if scheme == "file":
        src = Path(urlparse(url).path)
        if not src.is_file():
            return False, None, f"LOCAL_SOURCE_MISSING: {src}"
        shutil.copy(str(src), str(dest))
        return True, dest, "copied local file source"

    # https path — only when explicitly enabled (real networked acquisition run)
    if scheme == "https":
        if not allow_network:
            return False, None, "NETWORK_DISABLED (allow_network=false — dry-run scaffolding)"
        # --- networked run streams here; fail-soft so one bad URL/timeout never
        #     crashes an unattended continuous run (the recovery ladder decides
        #     next move on the resulting verification/fetch failure) -----------
        import time  # noqa: E402
        import urllib.request  # noqa: E402  (only imported on the live path)
        net = rules["networking"]
        req = urllib.request.Request(url, headers={"User-Agent": net["user_agent"]})
        try:
            with urllib.request.urlopen(req, timeout=net["read_timeout_seconds"]) as resp, dest.open("wb") as fh:
                shutil.copyfileobj(resp, fh, length=net["chunk_bytes"])
        except Exception as exc:  # noqa: BLE001 — any network error is an expected, recoverable fetch failure
            if dest.exists():
                dest.unlink(missing_ok=True)
            return False, None, f"NETWORK_ERROR: {type(exc).__name__}: {exc}"
        # politeness: honour the configured inter-request delay on the live path
        time.sleep(net.get("polite_delay_seconds", 0))
        return True, dest, "downloaded via https"
    return False, None, f"UNSUPPORTED_SCHEME: {scheme}"


def _due(entry: dict, ignore_backoff: bool) -> bool:
    if entry.get("status") == "RETRY_PENDING" and not ignore_backoff:
        nr = entry.get("next_retry")
        if nr:
            try:
                return datetime.now(timezone.utc) >= datetime.strptime(nr, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            except ValueError:
                return True
    return True


def run(root: Path, allow_network: bool = False, ignore_backoff: bool = False,
        limit: int | None = None) -> dict:
    ws = Workspace(root)
    rules = ws.config("download_rules")
    allow_network = allow_network or rules.get("allow_network", False)
    engine = get_engine(root)

    queue = load_json(ws.pm("download_queue"), []) or []
    board_seq = {b["code"]: b["sequence"] for b in ws.config("boards")["boards"].values()}
    class_order = [c["class_label"] for c in ws.config("classes")["classes"].values()]
    cat_order = rules["within_subject_download_order"]
    queue.sort(key=lambda e: _order_key(e, board_seq, class_order, cat_order))

    stats = {"processed": 0, "verified": 0, "duplicate": 0, "failed": 0, "skipped": 0, "missing": 0}
    ws.append_session([f"\n## downloader session {utcnow()}",
                       f"- mode: {'network' if allow_network else 'dry-run (network disabled)'}",
                       f"- queue size: {len(queue)}"])

    for entry in queue:
        if limit is not None and stats["processed"] >= limit:
            break
        rid = entry.get("resource_id")
        if entry.get("status") in TERMINAL:
            stats["skipped"] += 1
            continue
        if not _due(entry, ignore_backoff):
            stats["skipped"] += 1
            continue

        ok, incoming, note = _fetch(entry, ws, rules, allow_network)
        entry["last_attempt"] = utcnow()
        if not ok:
            entry["status"] = "SKIPPED"
            entry["last_note"] = note
            stats["skipped"] += 1
            ws.log("download", f"SKIP {rid}: {note}")
            continue

        entry["status"] = "DOWNLOADED"
        entry["download_timestamp"] = utcnow()
        expected = dict(entry)
        expected.setdefault("source_url", entry.get("source_url"))
        result = engine.verify_resource(expected, incoming)
        stats["processed"] += 1
        ws.log("verification", f"{result.status} {rid}: {result.reason_code or 'ok'}")

        if result.status == "VERIFIED":
            entry["status"] = "VERIFIED"
            stats["verified"] += 1
        elif result.status == "DUPLICATE":
            entry["status"] = "VERIFIED"  # content already in repo; queue cell satisfied
            entry["duplicate_of"] = result.detail
            stats["duplicate"] += 1
        else:
            stats["failed"] += 1
            action = engine.next_recovery_action(rid)
            entry["status"] = {"RETRY": "RETRY_PENDING",
                               "TRY_ALTERNATIVE": "RETRY_PENDING",
                               "RECORD_MISSING": "NOT_PUBLICLY_AVAILABLE",
                               "NONE": "FAILED"}.get(action.get("action"), "FAILED")
            entry["recovery"] = action
            if action.get("action") == "TRY_ALTERNATIVE":
                entry["source_url"] = action.get("url")
            if action.get("action") == "RECORD_MISSING":
                engine.record_missing(entry, entry.get("search_locations", []),
                                      f"all sources exhausted; last failure {result.reason_code}")
                stats["missing"] += 1
            # sync the backoff `next_retry` the engine recorded onto the queue entry
            failed = load_json(ws.pm("failed_downloads"), []) or []
            fe = next((f for f in failed if f.get("resource_id") == rid), None)
            if fe:
                entry["next_retry"] = fe.get("next_retry")

    write_json(ws.pm("download_queue"), queue)
    engine.generate_report()
    ws.append_session([f"- result: {stats}"])
    ws.log("download", f"session done: {stats}")
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--allow-network", action="store_true",
                    help="enable https fetching (real acquisition run; off by default per R1)")
    ap.add_argument("--ignore-backoff", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()
    stats = run(args.workspace, allow_network=args.allow_network,
                ignore_backoff=args.ignore_backoff, limit=args.limit)
    print(f"downloader: {stats}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
