#!/usr/bin/env python3
"""Convert any remaining sync Provider blocks that contain await into FutureProvider pattern."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PROVIDER_FILES = sorted(
    p
    for patterns in [
        "lib/features/finance/**/*provider*.dart",
        "lib/features/admissions/**/*provider*.dart",
        "lib/features/sis/**/*provider*.dart",
        "lib/features/transport/transport_providers.dart",
        "lib/features/hr/hr_providers.dart",
        "lib/features/hostel/hostel_providers.dart",
        "lib/features/library/library_providers.dart",
        "lib/features/inventory/inventory_providers.dart",
        "lib/features/alumni/alumni_providers.dart",
        "lib/features/control_center/control_center_providers.dart",
        "lib/features/management/management_providers.dart",
    ]
    for pat in [patterns]
    for p in ROOT.glob(pat)
    if p.is_file()
)


def provider_base(name: str) -> str:
    return name[:-8] if name.endswith("Provider") else name


def find_matching_brace(text: str, open_idx: int) -> int:
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1


def convert_provider_block(full: str, content: str) -> str:
    m = re.match(
        r"final (\w+) = (Provider(?:\.family)?(?:<[^;]+?>)+)\(\s*"
        r"(?:\(([^)]+)\)\s*,\s*)?"
        r"\(ref(?:,\s*(\w+))?\)\s*\{",
        full,
        re.DOTALL,
    )
    if not m:
        return full
    pname, pdecl, _, family_arg = m.groups()
    if pname.endswith("FutureProvider"):
        return full
    if "await" not in full:
        return full

    base = provider_base(pname)
    future_name = f"{base}FutureProvider"
    if future_name in content and f"final {future_name}" in content:
        # remove duplicate future if re-processing broken block
        pass

    body_start = full.index("{") + 1
    body_end = full.rindex("}")
    body = full[body_start:body_end]

    loading = f"{base}LoadingProvider"
    error = f"{base}ErrorProvider"
    empty = f"{base}EmptyProvider"

    future_lines = []
    for line in body.split("\n"):
        s = line.strip()
        if "LoadingProvider" in s and s.startswith("if ("):
            continue
        if "ErrorProvider" in s and s.startswith("if ("):
            continue
        if "EmptyProvider" in s and s.startswith("if ("):
            continue
        if s in ("return null;", "return const [];"):
            continue
        future_lines.append(line.replace("await ", "", 1) if "await ref.read" in line else line)

    future_body = "\n".join(future_lines).strip()

    # extract return type from pdecl
    type_match = re.search(r"<([^>]+(?:<[^>]+>)?[^>]*?)>", pdecl)
    ptype = type_match.group(1) if type_match else "dynamic"

    manual = []
    manual.append(
        f"manualLoading: ref.watch({loading})," if loading in content else "manualLoading: false,"
    )
    manual.append(
        f"manualError: ref.watch({error})," if error in content else "manualError: false,"
    )
    manual.append(
        f"manualEmpty: ref.watch({empty})," if empty in content else "manualEmpty: false,"
    )

    default = ""
    if ptype.startswith("List<") and "?" not in ptype.split("List<")[0]:
        default = " ?? const []"

    inner = pdecl.replace("Provider", "")
    if family_arg:
        future_decl = (
            f"final {future_name} = FutureProvider{inner}((ref, {family_arg}) async {{\n"
            f"{future_body}\n}});\n\n"
        )
        watch = f"ref.watch({future_name}({family_arg}))"
        sync = (
            f"final {pname} = {pdecl}((ref, {family_arg}) {{\n"
            f"  return watchRepositoryFuture(\n"
            f"    ref,\n"
            f"    {watch},\n"
            f"    {' '.join(manual)}\n"
            f"  ){default};\n"
            f"}});"
        )
    else:
        future_decl = (
            f"final {future_name} = FutureProvider{inner}((ref) async {{\n"
            f"{future_body}\n}});\n\n"
        )
        watch = f"ref.watch({future_name})"
        sync = (
            f"final {pname} = {pdecl}((ref) {{\n"
            f"  return watchRepositoryFuture(\n"
            f"    ref,\n"
            f"    {watch},\n"
            f"    {' '.join(manual)}\n"
            f"  ){default};\n"
            f"}});"
        )

    return future_decl + sync


def convert_arrow_provider(full: str, content: str) -> str:
    m = re.match(
        r"final (\w+) = (Provider<[^>]+>)\(\s*\(ref\)\s*=>\s*(.+),\s*\);",
        full,
        re.DOTALL,
    )
    if not m:
        return full
    pname, pdecl, expr = m.groups()
    if "await" not in expr or pname.endswith("FutureProvider"):
        return full

    base = provider_base(pname)
    future_name = f"{base}FutureProvider"
    expr_clean = expr.strip().replace("await ", "", 1)
    type_match = re.search(r"<([^>]+)>", pdecl)
    ptype = type_match.group(1) if type_match else "dynamic"
    default = " ?? const []" if ptype.startswith("List<") and "?" not in ptype else ""
    inner = pdecl.replace("Provider", "")

    return (
        f"final {future_name} = FutureProvider{inner}((ref) async =>\n"
        f"    {expr_clean});\n\n"
        f"final {pname} = {pdecl}((ref) =>\n"
        f"    watchRepositoryFuture(\n"
        f"      ref,\n"
        f"      ref.watch({future_name}),\n"
        f"      manualLoading: false,\n"
        f"      manualError: false,\n"
        f"      manualEmpty: false,\n"
        f"    ){default});"
    )


def fix_file(path: Path) -> bool:
    original = path.read_text()
    content = original

    # fix broken .map newline
    content = content.replace(
        ".map\n        (handoff)",
        ".map(\n        (handoff)",
    )

    # process provider declarations
    idx = 0
    pieces = []
    while True:
        start = content.find("final ", idx)
        if start == -1:
            pieces.append(content[idx:])
            break
        pieces.append(content[idx:start])
        # find end of this declaration (semicolon after balanced parens/braces)
        j = start + 6
        depth_paren = 0
        depth_brace = 0
        in_string = False
        end = -1
        while j < len(content):
            c = content[j]
            if c == "'" and content[j - 1 : j + 2] != "\\'":
                in_string = not in_string
            if not in_string:
                if c == "(":
                    depth_paren += 1
                elif c == ")":
                    depth_paren -= 1
                elif c == "{":
                    depth_brace += 1
                elif c == "}":
                    depth_brace -= 1
                elif c == ";" and depth_paren == 0 and depth_brace == 0:
                    end = j + 1
                    break
            j += 1
        if end == -1:
            pieces.append(content[start:])
            break
        decl = content[start:end]
        if decl.startswith("final ") and "Provider" in decl and "FutureProvider" not in decl.split("=")[0]:
            if "await" in decl:
                decl = convert_provider_block(decl, content)
            elif "=>" in decl and "RepositoryProvider" in decl:
                decl = convert_arrow_provider(decl, content)
        pieces.append(decl)
        idx = end

    content = "".join(pieces)

    # remove duplicate FutureProvider blocks (keep first)
    seen_futures = set()
    lines = content.split("\n")
    out = []
    skip_until_blank = False
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"final (\w+FutureProvider)", line)
        if m:
            name = m.group(1)
            if name in seen_futures:
                # skip this future provider block
                brace = 0
                while i < len(lines):
                    brace += lines[i].count("{") - lines[i].count("}")
                    i += 1
                    if brace <= 0 and lines[i - 1].strip().endswith("});"):
                        break
                continue
            seen_futures.add(name)
        out.append(line)
        i += 1
    content = "\n".join(out)

    if content != original:
        path.write_text(content)
        return True
    return False


def main():
    modified = []
    for path in PROVIDER_FILES:
        if fix_file(path):
            modified.append(str(path.relative_to(ROOT)))
    print(f"Fixed v2: {len(modified)}")
    for f in modified:
        print(f"  {f}")


if __name__ == "__main__":
    main()
