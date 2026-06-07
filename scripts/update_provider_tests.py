#!/usr/bin/env python3
"""Insert await container.read(XFutureProvider.future) before sync provider reads in tests."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def future_name(sync: str) -> str:
    if sync.endswith("Provider"):
        return sync[:-8] + "FutureProvider"
    return sync + "Future"


def collect_future_providers(test_path: Path, content: str) -> set[str]:
    futures = set()
    for m in re.finditer(r"import 'package:akshara_erp/([^']+)';", content):
        rel = m.group(1)
        dart = ROOT / "lib" / rel
        if dart.is_file():
            text = dart.read_text()
            futures.update(re.findall(r"final (\w+FutureProvider)", text))
    return futures


def update_test_file(path: Path) -> bool:
    content = path.read_text()
    original = content

    content = re.sub(r"test\('([^']+)', \(\) \{", r"test('\1', () async {", content)
    futures = collect_future_providers(path, content)

    def patch_test_body(body: str) -> str:
        reads = set(re.findall(r"container\.read\((\w+Provider)\)", body))
        reads.update(
            re.findall(r"container\.read\((\w+Provider)\([^)]+\)\)", body)
        )
        to_await = sorted(
            future_name(r) for r in reads if future_name(r) in futures
        )
        if not to_await:
            return body
        if any(f"await container.read({f}.future)" in body for f in to_await):
            return body

        lines = body.split("\n")
        insert_at = 0
        for idx, line in enumerate(lines):
            if "ProviderContainer(" in line or "container = ProviderContainer" in line:
                insert_at = idx + 1
            if "addTearDown" in line:
                insert_at = idx + 1
            if "setUp(" in line:
                insert_at = idx + 1

        indent = "      "
        for line in lines:
            if line.strip().startswith("final data") or line.strip().startswith(
                "expect("
            ):
                m = re.match(r"^(\s+)", line)
                if m:
                    indent = m.group(1)
                break

        # dedupe while preserving order
        seen = set()
        unique_awaits = []
        for f in to_await:
            if f not in seen:
                seen.add(f)
                unique_awaits.append(f"{indent}await container.read({f}.future);")

        return "\n".join(lines[:insert_at] + unique_awaits + lines[insert_at:])

    # split by test blocks
    pattern = re.compile(r"test\('([^']+)', \(\) async \{", re.MULTILINE)
    parts = []
    last = 0
    for m in pattern.finditer(content):
        parts.append(content[last : m.start()])
        parts.append(m.group(0))
        start = m.end()
        depth = 1
        i = start
        while i < len(content) and depth > 0:
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
            i += 1
        body = content[start : i - 1]
        parts.append(patch_test_body(body))
        parts.append("}")
        last = i
    parts.append(content[last:])
    content = "".join(parts)

    if content != original:
        path.write_text(content)
        return True
    return False


def main():
    test_files = sorted(
        set(ROOT.glob("test/features/**/*provider*test*.dart"))
        | set(ROOT.glob("test/features/**/*providers*test*.dart"))
    )
    modified = []
    for path in test_files:
        if update_test_file(path):
            modified.append(str(path.relative_to(ROOT)))
    print(f"Updated {len(modified)} provider test files")
    for f in modified:
        print(f"  {f}")


if __name__ == "__main__":
    main()
