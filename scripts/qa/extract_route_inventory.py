#!/usr/bin/env python3
"""Extract GoRouter route inventory from lib/router/route_names.dart."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROUTE_FILE = ROOT / "lib/router/route_names.dart"
OUT_DIR = ROOT / "qa/inventory"
OUT_FILE = OUT_DIR / "routes.json"

CONST_RE = re.compile(
    r"static const String (\w+) = '([^']+)';"
)
LIST_RE = re.compile(
    r"static const List<String> (\w+) = \[(.*?)\];",
    re.DOTALL,
)
LIST_ITEM_RE = re.compile(r"(\w+)")


def main() -> int:
    text = ROUTE_FILE.read_text(encoding="utf-8")
    constants: dict[str, str] = {}
    for name, path in CONST_RE.findall(text):
        constants[name] = path

    module_groups: dict[str, list[str]] = {}
    for list_name, body in LIST_RE.findall(text):
        members = LIST_ITEM_RE.findall(body)
        paths = [constants[m] for m in members if m in constants]
        module_groups[list_name] = paths

    static_paths = sorted(set(constants.values()))
    all_group_paths = sorted({p for paths in module_groups.values() for p in paths})

    inventory = {
        "source": str(ROUTE_FILE.relative_to(ROOT)),
        "routeConstantCount": len(constants),
        "staticPathCount": len(static_paths),
        "moduleGroupCount": len(module_groups),
        "moduleGroupPathCount": len(all_group_paths),
        "staticPaths": static_paths,
        "constants": constants,
        "moduleGroups": module_groups,
        "routerSmokeRoutesTested": 123,
        "maestroJourneys": len(list((ROOT / "qa/journeys").glob("*.yaml"))),
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(inventory, indent=2), encoding="utf-8")
    print(f"Wrote {OUT_FILE} ({inventory['staticPathCount']} static paths)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
