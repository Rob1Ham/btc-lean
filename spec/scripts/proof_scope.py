#!/usr/bin/env python3
"""proof_scope.py — static proof-scope index for the `spec/proofs` package.

This script inventories the Lean proof package from tracked source paths and
`import` lines only. It never invokes Lean or Lake, resolves declarations, or
checks proofs.

MODULE-COUNT CONVENTION
-----------------------
A *module* is a tracked `.lean` file under `spec/proofs`, excluding:

  * `spec/proofs/lakefile.lean` — Lake package configuration, not a Lean module;
  * anything under `.lake/` or `__pycache__/` — build and cache trees.

Every other `.lean` file is a module, including tests, probes, and experimental
modules that are outside the default build target. A module's name is its path
relative to `spec/proofs`, with the `.lean` suffix removed and `/` replaced by
`.`:

  spec/proofs/BitcoinProofs.lean                  -> BitcoinProofs
  spec/proofs/BitcoinProofs/Trivial.lean          -> BitcoinProofs.Trivial
  spec/proofs/BitcoinProofs/AF/PDW10/PDW10Guards.lean
      -> BitcoinProofs.AF.PDW10.PDW10Guards

The module count is derived from tracked sources. The one non-module
configuration file is `lakefile.lean`.

DEFAULT CLOSURE
---------------
The default closure is the root module `BitcoinProofs` plus every module
reachable through `import` lines whose imported name exists in the module set.
Imports of packages outside `spec/proofs` (for example `Bitcoin.*`, `Mathlib`,
or `Batteries`) do not contribute local closure members and are ignored here.
Import lines are read literally; no Lean-side import resolution is performed.

CLI
---
  python3 spec/scripts/proof_scope.py
      Regenerate docs/PROOF-SCOPE.md in place.

  python3 spec/scripts/proof_scope.py --check
      Regenerate in memory, print a unified diff if the committed page is
      stale, and validate the module/closure/outside counts stated in
      docs/PROOF-BUILD.md. Never writes a file; exits 1 on any mismatch.
"""

from __future__ import annotations

import argparse
import difflib
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
PROOFS = REPO / "spec" / "proofs"
ROOT_MODULE = "BitcoinProofs"
ROOT_FILE = PROOFS / "BitcoinProofs.lean"
OUT = REPO / "docs" / "PROOF-SCOPE.md"
BUILD_DOC = REPO / "docs" / "PROOF-BUILD.md"

EXCLUDED_DIRS = {".lake", "__pycache__"}
EXCLUDED_FILES = {"lakefile.lean"}


class ScopeError(Exception):
    """A static input needed by the index is missing or malformed."""


def tracked_lean_files() -> list[Path]:
    """Return every tracked `.lean` file under `spec/proofs`, sorted by path."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(REPO), "ls-files", "-z", "--", "spec/proofs"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ScopeError("git is required to enumerate tracked proof files") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.decode("utf-8", "replace").strip()
        raise ScopeError(f"git ls-files failed: {detail}") from exc

    files: list[Path] = []
    for raw in proc.stdout.decode("utf-8").split("\0"):
        if not raw or not raw.endswith(".lean"):
            continue
        path = REPO / raw
        try:
            path.relative_to(PROOFS)
        except ValueError:
            continue
        if not path.is_file():
            raise ScopeError(f"tracked Lean file is missing from the worktree: {raw}")
        files.append(path)
    return sorted(files)


def is_module_file(path: Path) -> bool:
    """True when a tracked `.lean` file is a Lean module, not Lake config."""
    rel = path.relative_to(PROOFS)
    if any(part in EXCLUDED_DIRS for part in rel.parts):
        return False
    return rel.name not in EXCLUDED_FILES


def module_name(path: Path) -> str:
    rel = path.relative_to(PROOFS)
    return rel.with_suffix("").as_posix().replace("/", ".")


def imports_of(path: Path) -> list[str]:
    """Read literal `import` lines; ignore comments and non-import lines."""
    imports: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        if parts[0] == "public" and len(parts) > 2 and parts[1] == "import":
            parts = parts[1:]
        if parts[0] != "import" or len(parts) < 2:
            continue
        name = parts[1]
        if name == "all" and len(parts) > 2:
            name = parts[2]
        imports.append(name)
    return imports


def collect_scope() -> dict:
    lean_files = tracked_lean_files()
    files = [path for path in lean_files if is_module_file(path)]
    paths = {module_name(path): path for path in files}
    if len(paths) != len(files):
        raise ScopeError("two tracked Lean files map to the same module name")
    if ROOT_MODULE not in paths:
        raise ScopeError(f"root module not found: {ROOT_FILE}")

    imports = {name: imports_of(path) for name, path in paths.items()}
    closure: set[str] = set()
    stack = [ROOT_MODULE]
    while stack:
        module = stack.pop()
        if module in closure:
            continue
        closure.add(module)
        for imported in imports[module]:
            if imported in paths and imported not in closure:
                stack.append(imported)

    outside = sorted(set(paths) - closure)
    closure_sorted = sorted(closure)

    def area(module: str) -> str:
        if module == ROOT_MODULE:
            return "(root)"
        parts = module.split(".")
        if len(parts) > 1 and parts[0] == ROOT_MODULE:
            return parts[1]
        return parts[0]

    areas: dict[str, list[str]] = {}
    for module in sorted(paths):
        areas.setdefault(area(module), []).append(module)

    return {
        "lean_files": lean_files,
        "files": files,
        "modules": paths,
        "imports": imports,
        "closure": closure_sorted,
        "outside": outside,
        "areas": areas,
    }


def render(scope: dict) -> str:
    modules = scope["modules"]
    closure = scope["closure"]
    outside = scope["outside"]
    areas = scope["areas"]
    closure_set = set(closure)
    outside_set = set(outside)

    lines: list[str] = []
    add = lines.append

    add("# Proof scope")
    add("")
    add("<!-- Generated by `spec/scripts/proof_scope.py`; do not edit by hand. -->")
    add("")
    add(
        "This page is the static scope index for the Lean proof package at "
        "`spec/proofs`. It is derived from tracked file paths and `import` "
        "lines only: no Lean build, declaration resolution, or proof checking "
        "is involved."
    )
    add("")
    add("## Counts")
    add("")
    add("| Metric | Count |")
    add("|---|---:|")
    add(
        f"| Tracked `.lean` files under `spec/proofs` | "
        f"{len(scope['lean_files'])} |"
    )
    add(f"| Lean modules | {len(modules)} |")
    add("| Non-module `.lean` files | 1 (`lakefile.lean`) |")
    add(f"| Modules in the default `BitcoinProofs` closure | {len(closure)} |")
    add(f"| Modules outside the default closure | {len(outside)} |")
    add("")
    add(
        f"The package has {len(scope['lean_files'])} tracked `.lean` files: "
        f"{len(modules)} modules plus the Lake build file "
        "`spec/proofs/lakefile.lean`, which is not a module."
    )
    add("")
    add("## Module-count convention")
    add("")
    add(
        "A **module** is a tracked `.lean` file under `spec/proofs`, excluding "
        "`lakefile.lean` and files under `.lake/` or `__pycache__/`. Every "
        "other `.lean` file counts, including tests, probes, and experimental "
        "modules outside the default build target."
    )
    add("")
    add(
        "A module name is its path relative to `spec/proofs`, with `.lean` "
        "removed and `/` replaced by `.` — for example "
        "`spec/proofs/BitcoinProofs/AF/PDW10/PDW10Guards.lean` is "
        "`BitcoinProofs.AF.PDW10.PDW10Guards`. The root module "
        "`BitcoinProofs` is `spec/proofs/BitcoinProofs.lean`."
    )
    add("")
    add(
        "The **default closure** is the root module plus every module "
        "reachable through `import` lines whose imported name exists in this "
        "module set. Imports of `Bitcoin.*`, `Mathlib`, `Batteries`, and "
        "other external packages are ignored for local closure membership."
    )
    add("")
    add(
        "`docs/PROOF-BUILD.md` records a historical build census of 381 "
        "outside-closure `.lean` files, one more than the 380 outside-closure "
        "modules counted here. The 381 total equals the 410 tracked `.lean` "
        "files minus the 29-module closure, so it includes the non-module "
        "`lakefile.lean`; it is a build record and is not regenerated by this "
        "script."
    )
    add("")
    add("## Default closure")
    add("")
    add(
        f"The root has {len(scope['imports'][ROOT_MODULE])} direct imports. "
        f"Their transitive local closure is {len(closure)} modules:"
    )
    add("")
    for module in closure:
        add(f"- `{module}`")
    add("")
    add("## Inventory by top-level area")
    add("")
    add(
        "The top-level area is the first path component after `BitcoinProofs`; "
        "the root module is shown as `(root)`. Areas and modules are "
        "alphabetical."
    )
    add("")
    add("| Area | Modules | In closure | Outside closure |")
    add("|---|---:|---:|---:|")
    for area_name in sorted(areas):
        members = areas[area_name]
        in_closure = sum(1 for module in members if module in closure_set)
        outside_count = sum(1 for module in members if module in outside_set)
        add(f"| `{area_name}` | {len(members)} | {in_closure} | {outside_count} |")
    add(
        f"| **Total** | **{len(modules)}** | **{len(closure)}** | "
        f"**{len(outside)}** |"
    )
    add("")
    for area_name in sorted(areas):
        members = areas[area_name]
        in_closure = sum(1 for module in members if module in closure_set)
        add(
            f"<details><summary><code>{area_name}</code> — {len(members)} "
            f"modules ({in_closure} in closure)</summary>"
        )
        add("")
        for module in members:
            add(f"- `{module}`")
        add("")
        add("</details>")
        add("")

    return "\n".join(lines).rstrip() + "\n"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def validate_build_counts(scope: dict) -> list[str]:
    """Validate counts stated in docs/PROOF-BUILD.md."""
    text = read_text(BUILD_DOC)
    if not text:
        return [f"{BUILD_DOC.relative_to(REPO)} is missing or empty"]

    expected = {
        "module count": len(scope["modules"]),
        "Lean file count": len(scope["lean_files"]),
        "closure count": len(scope["closure"]),
        "outside-closure count": len(scope["outside"]),
    }
    patterns = {
        "module count": r"\*\*(\d+)\s+Lean modules\*\*",
        "Lean file count": r"\((\d+)\s+`\.lean` files including\s+`lakefile\.lean`\)",
        "closure count": r"imports:\s*\*\*(\d+)\s+modules\*\*",
        "outside-closure count": (
            r"\*\*(\d+)\s+modules are\s+outside the default closure\*\*"
        ),
        "table closure count": (
            r"^\|\s*Default\s+`BitcoinProofs`\s+closure\s*\|\s*(\d+)\s+modules?\s*\|"
        ),
        "table outside-closure count": (
            r"^\|\s*Outside the default closure\s*\|\s*\d+\s+entries\s+"
            r"\((\d+)\s+modules"
        ),
    }
    table_expected = {
        "table closure count": len(scope["closure"]),
        "table outside-closure count": len(scope["outside"]),
    }

    errors: list[str] = []
    for label, pattern in patterns.items():
        match = re.search(pattern, text, re.MULTILINE)
        if match is None:
            errors.append(f"could not find the {label} statement")
            continue
        actual = int(match.group(1))
        want = expected.get(label, table_expected.get(label))
        if actual != want:
            errors.append(f"{label}: document says {actual}, expected {want}")
    return errors


def print_diff(old: str, new: str) -> None:
    rel = OUT.relative_to(REPO).as_posix()
    diff = difflib.unified_diff(
        old.splitlines(keepends=True),
        new.splitlines(keepends=True),
        fromfile=rel,
        tofile=f"{rel} (generated)",
    )
    sys.stdout.writelines(diff)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the generated page and PROOF-BUILD.md counts; never write",
    )
    args = parser.parse_args()

    try:
        scope = collect_scope()
    except ScopeError as exc:
        print(f"proof-scope: {exc}", file=sys.stderr)
        return 1

    generated = render(scope)

    if not args.check:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(generated, encoding="utf-8")
        print(
            "proof-scope: wrote "
            f"{OUT.relative_to(REPO)} "
            f"({len(scope['modules'])} modules, "
            f"{len(scope['closure'])} in closure, "
            f"{len(scope['outside'])} outside)"
        )
        return 0

    failed = False
    current = read_text(OUT)
    if current != generated:
        failed = True
        print(
            f"proof-scope: {OUT.relative_to(REPO)} is stale; "
            "regenerate with spec/scripts/proof_scope.py",
            file=sys.stderr,
        )
        print_diff(current, generated)

    for error in validate_build_counts(scope):
        failed = True
        print(
            f"proof-scope: {BUILD_DOC.relative_to(REPO)}: {error}",
            file=sys.stderr,
        )

    if failed:
        return 1

    print(
        "proof-scope: "
        f"{OUT.relative_to(REPO)} and {BUILD_DOC.relative_to(REPO)} "
        "counts are current"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
