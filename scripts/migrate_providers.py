#!/usr/bin/env python3
"""Migrate feature providers to FutureProvider + tenant-aware repo calls."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INTERFACES = ROOT / "lib/core/repositories/interfaces"

PROVIDER_FILES = sorted(
    set(
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
)


def load_method_params() -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for iface in INTERFACES.glob("*.dart"):
        text = iface.read_text()
        for m in re.finditer(
            r"Future<[^>]+>\s+(\w+)\(\{([^}]+)\}\);",
            text,
        ):
            name = m.group(1)
            inner = m.group(2)
            names = []
            for part in inner.split(","):
                part = part.strip()
                if part.startswith("required ") and "query" not in part:
                    names.append(part.split()[-1])
            result[name] = names
    return result


METHOD_PARAMS = load_method_params()


def core_prefix(filepath: Path) -> str:
    rel = filepath.parent.relative_to(ROOT / "lib/features")
    return "../" * (len(rel.parts) + 1)


def repo_call(method: str, positional: str = "") -> str:
    parts = ["query: ref.watch(repositoryQueryProvider)"]
    if positional.strip():
        pos = [a.strip() for a in positional.split(",") if a.strip()]
        for i, pname in enumerate(METHOD_PARAMS.get(method, [])):
            if i < len(pos):
                parts.append(f"{pname}: {pos[i]}")
    return f"{method}({', '.join(parts)})"


def transform_content(content: str, filepath: Path) -> str:
    prefix = core_prefix(filepath)
    if "tenant_provider.dart" not in content:
        content = content.replace(
            "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
            "import 'package:flutter_riverpod/flutter_riverpod.dart';\n\n"
            f"import '{prefix}core/tenant/tenant_provider.dart';\n"
            f"import '{prefix}core/providers/repository_future.dart';\n",
        )

    # ref.read(xxxRepositoryProvider).method(args)
    def repl_read(m: re.Match) -> str:
        repo = m.group(1)
        method = m.group(2)
        args = (m.group(3) or "").strip()
        return f"await ref.read({repo}).{repo_call(method, args)}"

    content = re.sub(
        r"ref\.read\((\w+RepositoryProvider)\)\.(\w+)\(([^)]*)\)",
        repl_read,
        content,
    )
    content = re.sub(
        r"ref\.read\((\w+RepositoryProvider)\)\.(\w+)\(\)",
        repl_read,
        content,
    )

    # chained .method() after multiline read
    for method, pnames in METHOD_PARAMS.items():
        call = repo_call(method)
        content = re.sub(rf"\.{re.escape(method)}\(\)", f".{call}", content)
        if pnames:
            pname = pnames[0]
            content = re.sub(
                rf"\.{re.escape(method)}\((\w+)\)",
                f".{repo_call(method, r'\1')}",
                content,
            )

    return content


def provider_base(name: str) -> str:
    return name[:-8] if name.endswith("Provider") else name


def add_future_providers(content: str) -> str:
    """Insert FutureProvider siblings and rewrite data providers."""
    # Match final fooProvider = Provider<...>( (ref) { ... });
    pattern = re.compile(
        r"final (\w+) = (Provider(?:\.family)?<([^>]+)>)\(\s*"
        r"(?:\(([^)]+)\)\s*,\s*)?"
        r"\(ref(?:,\s*(\w+))?\)\s*\{([\s\S]*?)\}\s*,?\s*\);",
        re.MULTILINE,
    )

    def repl(m: re.Match) -> str:
        pname, pdecl, ptype, family_params, family_arg, body = m.groups()
        base = provider_base(pname)
        future_name = f"{base}FutureProvider"

        if future_name in content or "RepositoryProvider" not in body:
            return m.group(0)
        if "watchRepositoryFuture" in body:
            return m.group(0)

        loading = f"{base}LoadingProvider"
        error = f"{base}ErrorProvider"
        empty = f"{base}EmptyProvider"

        # Future body: strip guard returns
        future_lines = []
        for line in body.split("\n"):
            s = line.strip()
            if "LoadingProvider" in s and s.startswith("if ("):
                continue
            if "ErrorProvider" in s and s.startswith("if ("):
                continue
            if "EmptyProvider" in s and s.startswith("if ("):
                continue
            if s == "return null;" and (loading in body or error in body or empty in body):
                continue
            if s.startswith("return const [];") and (loading in body or error in body):
                continue
            future_lines.append(line)
        future_body = "\n".join(future_lines).strip()

        # multiline handoff fix
        if ".map(" in future_body and "await" not in future_body.split(".map")[0]:
            future_body = future_body.replace(
                "return handoffs",
                "return handoffs",
            )

        manual = []
        manual.append(
            f"manualLoading: ref.watch({loading}),"
            if loading in content
            else "manualLoading: false,"
        )
        manual.append(
            f"manualError: ref.watch({error}),"
            if error in content
            else "manualError: false,"
        )
        manual.append(
            f"manualEmpty: ref.watch({empty}),"
            if empty in content
            else "manualEmpty: false,"
        )

        default = ""
        if ptype.startswith("List<") and "?" not in ptype:
            default = " ?? const []"

        if family_arg:
            future_decl = (
                f"final {future_name} = FutureProvider{pdecl.replace('Provider', '')}"
                f"((ref, {family_arg}) async {{\n{future_body}\n}});\n\n"
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
            inner = pdecl.replace("Provider", "")
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

    return pattern.sub(repl, content)


def migrate_arrow_providers(content: str) -> str:
    """Handle single-expression Provider((ref) => repo call)."""
    pattern = re.compile(
        r"final (\w+) = (Provider<([^>]+)>)\(\s*\n?\s*\(ref\)\s*=>\s*([^,;]+),\s*\n?\s*\);",
        re.MULTILINE,
    )

    def repl(m: re.Match) -> str:
        pname, pdecl, ptype, expr = m.groups()
        base = provider_base(pname)
        future_name = f"{base}FutureProvider"
        if future_name in content:
            return m.group(0)
        if "RepositoryProvider" not in expr:
            return m.group(0)

        default = " ?? const []" if ptype.startswith("List<") else ""
        inner = pdecl.replace("Provider", "")
        return (
            f"final {future_name} = FutureProvider{inner}((ref) async =>\n"
            f"    {expr.strip()});\n\n"
            f"final {pname} = {pdecl}((ref) =>\n"
            f"    watchRepositoryFuture(\n"
            f"      ref,\n"
            f"      ref.watch({future_name}),\n"
            f"      manualLoading: false,\n"
            f"      manualError: false,\n"
            f"      manualEmpty: false,\n"
            f"    ){default});"
        )

    return pattern.sub(repl, content)


def main():
    modified = []
    for path in PROVIDER_FILES:
        original = path.read_text()
        content = transform_content(original, path)
        content = add_future_providers(content)
        content = migrate_arrow_providers(content)
        if content != original:
            path.write_text(content)
            modified.append(str(path.relative_to(ROOT)))
    print(f"Modified {len(modified)} provider files")
    for f in modified:
        print(f"  {f}")


if __name__ == "__main__":
    main()
