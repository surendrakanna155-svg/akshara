#!/usr/bin/env python3
"""Fix providers: convert remaining sync Providers with await to FutureProvider pattern."""
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


def fix_future_nullable(content: str) -> str:
    return re.sub(r"FutureProvider<([^>?]+)\?>", r"FutureProvider<\1>", content)


def fix_provider_block(match: re.Match, content: str) -> str:
    pname = match.group(1)
    pdecl = match.group(2)
    ptype = match.group(3)
    family_arg = match.group(4)
    body = match.group(5)

    if "await" not in body and "RepositoryProvider" not in body:
        return match.group(0)
    if pname.endswith("FutureProvider"):
        return match.group(0)

    base = provider_base(pname)
    future_name = f"{base}FutureProvider"
    if future_name in content:
        # maybe partial - still replace if body has await in sync provider
        pass

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
        if s == "return null;":
            continue
        if s == "return const [];":
            continue
        # strip await keyword for cleaner future body
        future_lines.append(line.replace("await ", "", 1) if "await ref.read" in line else line)

    future_body = "\n".join(future_lines).strip()
    if not future_body:
        return match.group(0)

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
    if ptype.startswith("List<") and "?" not in ptype:
        default = " ?? const []"

    inner = pdecl.replace("Provider", "")
    if family_arg:
        future_decl = (
            f"final {future_name} = FutureProvider{inner}((ref, {family_arg}) async {{\n"
            f"{future_body}\n}});\n\n"
        )
        watch = f"ref.watch({future_name}({family_arg}))"
        sync_decl = (
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
        sync_decl = (
            f"final {pname} = {pdecl}((ref) {{\n"
            f"  return watchRepositoryFuture(\n"
            f"    ref,\n"
            f"    {watch},\n"
            f"    {' '.join(manual)}\n"
            f"  ){default};\n"
            f"}});"
        )

    return future_decl + sync_decl


def fix_arrow_provider(match: re.Match, content: str) -> str:
    pname = match.group(1)
    pdecl = match.group(2)
    ptype = match.group(3)
    expr = match.group(4).strip()

    if "RepositoryProvider" not in expr or "await" not in expr:
        return match.group(0)
    if pname.endswith("FutureProvider"):
        return match.group(0)

    base = provider_base(pname)
    future_name = f"{base}FutureProvider"
    expr_clean = expr.replace("await ", "", 1)

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
    content = fix_future_nullable(original)

    block_pattern = re.compile(
        r"final (\w+) = (Provider(?:\.family)?<([^>]+)>)\(\s*"
        r"\(ref(?:,\s*(\w+))?\)\s*\{([\s\S]*?)\}\s*,?\s*\);",
        re.MULTILINE,
    )
    content = block_pattern.sub(lambda m: fix_provider_block(m, content), content)

    arrow_pattern = re.compile(
        r"final (\w+) = (Provider<([^>]+)>)\(\s*\n?\s*\(ref\)\s*=>\s*([^,;]+),\s*\n?\s*\);",
        re.MULTILINE,
    )
    content = arrow_pattern.sub(lambda m: fix_arrow_provider(m, content), content)

    # fix getFeeStructures missing academicYear
    content = content.replace(
        ".getFeeStructures(query: ref.watch(repositoryQueryProvider))",
        ".getFeeStructures(query: ref.watch(repositoryQueryProvider), academicYear: year)",
    )

    # fix admissions approved handoffs
    content = content.replace(
        """  return ref
      .read(admissionsRepositoryProvider)
      .getApprovedHandoffs()
      .map(""",
        """  final handoffs = await ref
      .read(admissionsRepositoryProvider)
      .getApprovedHandoffs(query: ref.watch(repositoryQueryProvider));
  return handoffs
      .map""",
    )

    content = content.replace(
        """  return ref
      .read(admissionsRepositoryProvider)
      .getPendingEnrollments()
      .map""",
        """  final enrollments = await ref
      .read(admissionsRepositoryProvider)
      .getPendingEnrollments(query: ref.watch(repositoryQueryProvider));
  return enrollments
      .map""",
    )

    if content != original:
        path.write_text(content)
        return True
    return False


def main():
    modified = []
    for path in PROVIDER_FILES:
        if fix_file(path):
            modified.append(str(path.relative_to(ROOT)))
    print(f"Fixed {len(modified)} files")
    for f in modified:
        print(f"  {f}")


if __name__ == "__main__":
    main()
