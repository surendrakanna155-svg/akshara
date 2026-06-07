#!/usr/bin/env python3
"""Migrate repository interfaces, mocks, and API repos to async tenant-aware pattern."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INTERFACES = ROOT / "lib/core/repositories/interfaces"
MOCKS = ROOT / "lib/core/repositories/mock"
API_REPOS = list((ROOT / "lib/core/repositories/api").glob("api_*_repository.dart"))


def parse_params(params: str) -> list[tuple[str, str]]:
    if not params.strip():
        return []
    result = []
    for p in params.split(","):
        p = p.strip()
        parts = p.split()
        if len(parts) == 2:
            result.append((parts[0], parts[1]))
    return result


def async_signature(ret: str, name: str, param_list: list[tuple[str, str]]) -> str:
    parts = ["required RepositoryQuery query"]
    for ptype, pname in param_list:
        parts.append(f"required {ptype} {pname}")
    return f"Future<{ret}> {name}({{{', '.join(parts)}}})"


def sync_signature(ret: str, name: str, param_list: list[tuple[str, str]]) -> str:
    if not param_list:
        return f"{ret} {name}()"
    inner = ", ".join(f"{t} {n}" for t, n in param_list)
    return f"{ret} {name}({inner})"


def parse_interface(path: Path) -> dict:
    content = path.read_text()
    methods = {}
    for m in re.finditer(r"^\s+([\w<>, ?]+)\s+(\w+)\(([^)]*)\);", content, re.M):
        ret, name, params = m.groups()
        methods[name] = (ret, parse_params(params))
    return methods


def transform_interface(path: Path) -> str:
    content = path.read_text()
    if "repository_query.dart" not in content:
        lines = content.split("\n")
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
        lines.insert(insert_at, "import '../repository_query.dart';")
        content = "\n".join(lines)

    def repl(m: re.Match) -> str:
        ret, name, params = m.group(1), m.group(2), m.group(3)
        return "  " + async_signature(ret, name, parse_params(params)) + ";"

    return re.sub(r"^  ([\w<>, ?]+)\s+(\w+)\(([^)]*)\);", repl, content, flags=re.M)


def transform_mock(path: Path, methods: dict) -> str:
    content = path.read_text()
    if "repository_query.dart" not in content:
        lines = content.split("\n")
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
        lines.insert(insert_at, "import '../repository_query.dart';")
        content = "\n".join(lines)

    for name, (ret, param_list) in methods.items():
        old = sync_signature(ret, name, param_list)
        new = async_signature(ret, name, param_list)
        # arrow function
        content = re.sub(
            rf"@override\s+{re.escape(old)}\s*=>",
            f"@override\n  {new} async =>",
            content,
        )
        # block function
        content = re.sub(
            rf"@override\s+{re.escape(old)}\s*\{{",
            f"@override\n  {new} async {{",
            content,
        )
    return content


def transform_api(path: Path, methods: dict) -> str:
    content = path.read_text()
    if "repository_query.dart" not in content:
        content = content.replace(
            "import '../api_exception.dart';",
            "import '../api_exception.dart';\nimport '../../repository_query.dart';",
        )

    for name, (ret, param_list) in methods.items():
        old = sync_signature(ret, name, param_list)
        new = async_signature(ret, name, param_list)
        # one-line throw
        content = re.sub(
            rf"@override\s+{re.escape(old)}\s*=>\s*_notConnected\('{re.escape(name)}'\);",
            f"@override\n  {new} async => _notConnected('{name}');",
            content,
        )
        # block throw (unlikely)
        content = re.sub(
            rf"@override\s+{re.escape(old)}\s*=>\s*_notConnected\(",
            f"@override\n  {new} async => _notConnected(",
            content,
        )
    return content


def main():
    modified = []
    for iface in sorted(INTERFACES.glob("*.dart")):
        methods = parse_interface(iface)
        new_content = transform_interface(iface)
        if new_content != iface.read_text():
            iface.write_text(new_content)
            modified.append(str(iface.relative_to(ROOT)))

        mock_name = f"mock_{iface.stem.replace('_repository', '')}_repository.dart"
        # finance_repository -> mock_finance_repository
        stem = iface.stem  # e.g. finance_repository
        module = stem.replace("_repository", "")
        mock_path = MOCKS / f"mock_{module}_repository.dart"
        if mock_path.exists():
            new_mock = transform_mock(mock_path, methods)
            if new_mock != mock_path.read_text():
                mock_path.write_text(new_mock)
                modified.append(str(mock_path.relative_to(ROOT)))

        api_path = ROOT / f"lib/core/repositories/api/{module}/api_{module}_repository.dart"
        if api_path.exists():
            new_api = transform_api(api_path, methods)
            if new_api != api_path.read_text():
                api_path.write_text(new_api)
                modified.append(str(api_path.relative_to(ROOT)))

    print(f"Modified {len(modified)} repository files")
    for f in modified:
        print(f"  {f}")


if __name__ == "__main__":
    main()
