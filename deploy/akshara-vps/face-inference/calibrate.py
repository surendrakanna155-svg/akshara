"""Threshold calibration for 1:1 staff face verification.

Produces the empirical genuine/impostor score distributions from real pilot
captures and recommends a production threshold — or refuses to, and says why.

WHY A TOOL AND NOT A GUESS. The shipped default (0.40) is taken from published
ArcFace-family practice, not from measurement. A threshold that is too high
rejects genuine staff every morning; too low admits the wrong person to a
payroll record. Neither is discoverable without real faces, so this is the last
engineering step before pilot: the calibration itself is an operational task.

INPUT — one directory per staff member, containing that person's captures:

    captures/
      staff_0f2a.../   capture_1.png  capture_2.png  capture_3.png
      staff_71bd.../   capture_1.png  capture_2.png
      ...

Each file is an aligned 112x112 crop, exactly what the app sends. Capture at
least 3 per person across different sessions — different lighting, time of day,
with and without glasses — because that variation is what the threshold has to
survive in the field.

Directory names are used verbatim as identity labels. Use opaque staff IDs, NOT
names: this writes a CSV, and a CSV of who-resembles-whom keyed by name is
something you would rather not create.

USAGE

    python3 calibrate.py --captures ./captures --out calibration_2026-07-29.csv
    python3 calibrate.py --captures ./captures --target-far 0.0

Scores come from the RUNNING SERVICE by default, so the numbers are produced by
the exact path production uses — including face-presence validation and int8
quantisation. That matters: calibrating against a different code path would
produce a threshold that does not hold in production.
"""
from __future__ import annotations

import argparse
import base64
import csv
import itertools
import json
import os
import sys
import urllib.error
import urllib.request
from collections import defaultdict

import numpy as np


def embed_via_service(path: str, endpoint: str) -> list[float] | None:
    with open(path, "rb") as fh:
        crop = base64.b64encode(fh.read()).decode()
    req = urllib.request.Request(
        f"{endpoint.rstrip('/')}/embed",
        data=json.dumps({"crop": crop}).encode(),
        headers={"content-type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return json.loads(res.read())["embedding"]
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = json.loads(e.read()).get("detail", "")
        except Exception:
            pass
        print(f"  ! REJECTED {os.path.basename(path)}: {e.code} {detail}")
        return None
    except Exception as e:  # noqa: BLE001
        print(f"  ! FAILED {os.path.basename(path)}: {e}")
        return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", required=True, help="directory of <staff_id>/ subdirectories")
    ap.add_argument("--endpoint", default="http://127.0.0.1:8080")
    ap.add_argument("--out", default="calibration.csv", help="raw per-pair scores")
    ap.add_argument(
        "--target-far",
        type=float,
        default=0.0,
        help="max acceptable false-accept rate (default 0.0 — no impostor may pass)",
    )
    args = ap.parse_args()

    root = args.captures
    if not os.path.isdir(root):
        print(f"no such directory: {root}")
        return 2

    people: dict[str, list[str]] = defaultdict(list)
    for staff_id in sorted(os.listdir(root)):
        d = os.path.join(root, staff_id)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.lower().endswith((".png", ".jpg", ".jpeg")):
                people[staff_id].append(os.path.join(d, f))

    if len(people) < 2:
        print("Need captures from at least TWO people — impostor pairs are formed")
        print("across different people, so one person yields no impostor data.")
        return 2

    print(f"embedding captures via {args.endpoint} …")
    embeddings: dict[str, list[np.ndarray]] = defaultdict(list)
    rejected = 0
    for staff_id, files in people.items():
        for f in files:
            v = embed_via_service(f, args.endpoint)
            if v is None:
                rejected += 1
                continue
            a = np.asarray(v, dtype=np.float64)
            embeddings[staff_id].append(a / np.linalg.norm(a))
    if rejected:
        print(f"  {rejected} capture(s) rejected by the service — see above")

    usable = {k: v for k, v in embeddings.items() if len(v) >= 1}
    multi = {k: v for k, v in usable.items() if len(v) >= 2}
    if not multi:
        print("No staff member has 2+ usable captures, so there are no GENUINE")
        print("pairs to measure. Capture at least 2-3 per person.")
        return 2

    rows: list[tuple[str, str, str, float]] = []
    genuine: list[float] = []
    impostor: list[float] = []

    for staff_id, vs in multi.items():
        for a, b in itertools.combinations(range(len(vs)), 2):
            s = float(np.dot(vs[a], vs[b]))
            genuine.append(s)
            rows.append(("genuine", staff_id, staff_id, s))

    ids = sorted(usable)
    for i, j in itertools.combinations(range(len(ids)), 2):
        for va in usable[ids[i]]:
            for vb in usable[ids[j]]:
                s = float(np.dot(va, vb))
                impostor.append(s)
                rows.append(("impostor", ids[i], ids[j], s))

    with open(args.out, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["pair_type", "id_a", "id_b", "cosine"])
        w.writerows(rows)

    g = np.array(genuine)
    im = np.array(impostor)
    print()
    print(f"  people={len(usable)}  captures={sum(len(v) for v in usable.values())}")
    print(f"  GENUINE  pairs n={len(g):5d}  min={g.min():+.4f}  mean={g.mean():+.4f}  max={g.max():+.4f}")
    print(f"  IMPOSTOR pairs n={len(im):5d}  min={im.min():+.4f}  mean={im.mean():+.4f}  max={im.max():+.4f}")
    print(f"  raw scores written to {args.out}")

    # Equal error rate — where false accepts and false rejects cross.
    grid = np.unique(np.concatenate([g, im]))
    best_eer, eer_t = 1.0, None
    for t in grid:
        far = float((im >= t).mean())
        frr = float((g < t).mean())
        if abs(far - frr) < best_eer:
            best_eer, eer_t = abs(far - frr), (t, far, frr)
    if eer_t:
        print(f"  EER ~{(eer_t[1] + eer_t[2]) / 2:.4f} at threshold {eer_t[0]:+.4f}")

    print()
    if im.max() < g.min():
        # Separable: put the threshold in the middle of the gap so both lighting
        # drift (pushing genuine down) and a lookalike (pushing impostor up) have
        # room before either becomes an error.
        low, high = float(im.max()), float(g.min())
        rec = (low + high) / 2
        print("  ✅ SEPARABLE — genuine and impostor distributions do not overlap.")
        print(f"     gap: impostor max {low:+.4f} → genuine min {high:+.4f}")
        print(f"     RECOMMENDED THRESHOLD: {rec:.3f}")
        print()
        print(f"     Set FACE_MATCH_MIN_SIMILARITY={rec:.3f} on the edge service.")
        print("     Note the clamp band is [0.25, 0.99] — a value outside it is")
        print("     clamped, so widen MIN_SIMILARITY_THRESHOLD if you need lower.")
        return 0

    # Overlapping. Do NOT emit a single number as if it were safe.
    overlap = [s for s in im if s >= g.min()]
    print("  ⚠️  OVERLAP — some impostor pairs score at or above the weakest")
    print("     genuine pair. NO threshold separates them cleanly, so any value")
    print("     chosen here trades false accepts against false rejects.")
    print(f"     {len(overlap)} impostor pair(s) ≥ genuine minimum {g.min():+.4f}")
    print()
    print("     This usually means the CAPTURE PIPELINE, not the threshold:")
    print("       • inconsistent alignment or crop geometry")
    print("       • very different lighting between enrolment and verification")
    print("       • a mislabelled directory (two folders holding the same person)")
    print("     Fix the captures and re-run before choosing a number.")
    print()
    for far_target in sorted({args.target_far, 0.0, 0.001, 0.01}):
        cands = [t for t in grid if float((im >= t).mean()) <= far_target]
        if cands:
            t = float(min(cands))
            print(f"     FAR ≤ {far_target:<6} → threshold {t:+.4f} "
                  f"(rejects {float((g < t).mean()) * 100:.1f}% of genuine attempts)")
        else:
            print(f"     FAR ≤ {far_target:<6} → unreachable at any threshold")
    return 1


if __name__ == "__main__":
    sys.exit(main())
