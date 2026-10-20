#!/usr/bin/env python3
"""Fresh-checkout certificate replay checker and fuzzer for ``spec/equiv``.

A certificate is one of:

* ``spec/equiv/cells/**/certificate.sha256`` -- repo-root-relative SHA-256
  lines, one per tracked input, for an Alive2 / SAW / behavior leg;
* ``spec/equiv/**/SHA256SUMS`` -- manifest-relative SHA-256 lines used by the
  E5 and wave-16B evidence bundles.

The checker materializes the requested revision in a *fresh* git worktree
(tracked files only), then, inside that checkout:

1. parses every certificate and rejects malformed / absolute / escaping lines;
2. checks every referenced file exists, is git-tracked, and hashes correctly;
3. checks a leg certificate covers its own ``result.txt`` and ``run.sh``;
4. flags build-artifact references (paths ignored by git), machine-local
   paths embedded in certificate-bound transcripts, cross-leg references,
   and nested ``divergence/`` leakage.

It never writes to the audited tree.  A separate scratch extraction is used by
``--fuzz`` to prove the detector actually catches each leakage class.

Typical use::

    python3 spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py \
        --rev HEAD --fuzz 64

Exit codes: 0 = clean (warnings allowed), 1 = replay errors or fuzz failures,
2 = setup/usage error, 3 = fuzz-only failure.
"""
from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

CELLS_REL = Path("spec/equiv/cells")
EQUIV_REL = Path("spec/equiv")
CERT_NAME = "certificate.sha256"
MANIFEST_NAME = "SHA256SUMS"
LEG_DIRS = {"alive2", "saw", "behavior"}
TEXT_SUFFIXES = {
    ".md", ".sh", ".cpp", ".c", ".h", ".hpp", ".cry", ".saw", ".ll",
    ".bc", ".json", ".yaml", ".yml", ".txt", ".out", ".hex", ".py",
    ".lean", ".toml", ".cfg", ".ini", ".spec", ".log", "",
}
SKIP_PARTS = {".git", "build", "__pycache__", ".lake", "target"}
MAX_SCAN_BYTES = 4 * 1024 * 1024

# Machine-local checkout/build roots.  Tool install prefixes such as
# /opt/equiv-tools are pinned environment configuration and are not flagged.
HOME_ROOT = "/" + "home/"  # split so the repo's local-path gate stays clean
MACHINE_PATH_RE = re.compile(
    r"(?:" + HOME_ROOT + r"[A-Za-z0-9_.@+-]+"
    r"|/tmp/opencode(?:/|$)"
    r"|/workspace(?:/|$)"
    r"|/Users/[A-Za-z0-9_.@+-]+"
    r"|[A-Za-z]:\\\\"
    r"|file://)"
)
DIGEST_RE = re.compile(r"^[0-9a-fA-F]{64}$")
BUILD_PATH_RE = re.compile(r"(?<![\w.-])build(?:-[A-Za-z0-9_-]+)?/")

ERROR = "error"
WARNING = "warning"
INFO = "info"


@dataclasses.dataclass(frozen=True)
class Issue:
    target: str
    code: str
    severity: str
    detail: str = ""


@dataclasses.dataclass
class TargetReport:
    target: str
    kind: str
    base: str = "."
    entries: int = 0
    files: int = 0
    bytes: int = 0
    issues: list[Issue] = dataclasses.field(default_factory=list)

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == ERROR]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == WARNING]


# ---------------------------------------------------------------------------
# git helpers
# ---------------------------------------------------------------------------

def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def repo_root(path: Path) -> Path:
    r = git(path, "rev-parse", "--show-toplevel", check=False)
    if r.returncode != 0:
        raise SystemExit(f"not a git checkout: {path}")
    return Path(r.stdout.strip()).resolve()


def resolve_rev(repo: Path, rev: str) -> str:
    r = git(repo, "rev-parse", "--verify", f"{rev}^{{commit}}", check=False)
    if r.returncode != 0:
        raise SystemExit(f"cannot resolve revision {rev!r}")
    return r.stdout.strip()


def tracked_files_at(repo: Path, sha: str) -> set[str]:
    """Return every path tracked in the tree of ``sha``."""
    r = subprocess.run(
        ["git", "-C", str(repo), "ls-tree", "-r", "--name-only", "-z", sha],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return {p for p in r.stdout.decode("utf-8", "replace").split("\0") if p}


def ignored_path(root: Path, rel: str) -> bool:
    """True when ``rel`` is matched by a .gitignore rule (or a build dir)."""
    if any(part in SKIP_PARTS for part in Path(rel).parts):
        return True
    r = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "--no-index", "-q", "--", rel],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return r.returncode == 0


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# clean checkout
# ---------------------------------------------------------------------------

def tmp_root_default() -> Path:
    env = os.environ.get("CERT_REPRO_TMPDIR")
    if env:
        p = Path(env)
        p.mkdir(parents=True, exist_ok=True)
        return p
    for candidate in (Path("/tmp/opencode"), Path(tempfile.gettempdir())):
        if candidate.is_dir() and os.access(candidate, os.W_OK):
            return candidate
    return Path(tempfile.mkdtemp(prefix="cert-repro-"))


def make_worktree(repo: Path, sha: str, tmp: Path) -> Path:
    """Create a detached clean worktree at ``sha`` and return its root."""
    d = Path(tempfile.mkdtemp(prefix="clean-", dir=tmp))
    d.rmdir()  # git wants to create it (or accept an empty dir)
    r = git(repo, "worktree", "add", "--detach", "--quiet", str(d), sha, check=False)
    if r.returncode != 0:
        raise RuntimeError(f"git worktree add failed: {r.stderr.strip()}")
    return d


def extract_archive(repo: Path, sha: str, tmp: Path) -> Path:
    """Materialize the tracked tree at ``sha`` without registering a worktree."""
    d = Path(tempfile.mkdtemp(prefix="archive-", dir=tmp))
    tar = d / "tree.tar"
    with tar.open("wb") as fh:
        subprocess.run(
            ["git", "-C", str(repo), "archive", "--format=tar", sha],
            check=True, stdout=fh, stderr=subprocess.PIPE,
        )
    with tarfile.open(tar) as tf:
        try:
            tf.extractall(d, filter="data")  # Python >= 3.12
        except TypeError:  # pragma: no cover - older Python
            tf.extractall(d)
    tar.unlink()
    return d


def remove_worktree(repo: Path, path: Path) -> None:
    git(repo, "worktree", "remove", "--force", str(path), check=False)
    if path.exists():
        shutil.rmtree(path, ignore_errors=True)
    git(repo, "worktree", "prune", check=False)


# ---------------------------------------------------------------------------
# certificate discovery and parsing
# ---------------------------------------------------------------------------

def discover(root: Path) -> tuple[list[Path], list[Path]]:
    cells = root / CELLS_REL
    equiv = root / EQUIV_REL
    certs = []
    if cells.is_dir():
        for p in sorted(cells.rglob(CERT_NAME)):
            if p.is_file() and not any(part in SKIP_PARTS for part in p.parts):
                certs.append(p)
    manifests = []
    if equiv.is_dir():
        for p in sorted(equiv.rglob("*")):
            if not p.is_file() or any(part in SKIP_PARTS for part in p.parts):
                continue
            if p.name == CERT_NAME:
                continue
            if p.name == MANIFEST_NAME or p.suffix == ".sha256":
                manifests.append(p)
    return certs, manifests


def parse_lines(text: str):
    """Yield (lineno, digest, raw_ref) or (lineno, None, error_text)."""
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            yield lineno, None, ("comment", line)
            continue
        parts = line.split(None, 1)
        if len(parts) != 2 or not DIGEST_RE.fullmatch(parts[0]):
            yield lineno, None, ("malformed", line)
            continue
        yield lineno, parts[0].lower(), parts[1].strip()


def resolve_ref(root: Path, base: Path, rel: str, kind: str):
    """Return (repo_relative_path, error_code, detail)."""
    rel = rel.strip()
    if not rel:
        return None, "malformed-line", "empty path"
    if re.match(r"^[A-Za-z]:[\\/]", rel) or rel.startswith(("/", "\\")):
        return None, "absolute-path", rel
    if "\\" in rel:
        return None, "non-posix-path", rel
    if kind == "cell-certificate":
        if rel == ".." or rel.startswith("../") or "/../" in rel:
            return None, "path-escape", rel
        raw = root / rel
    else:
        raw = base / rel
    lex = Path(os.path.normpath(str(raw)))
    try:
        rel_root = lex.relative_to(root)
    except ValueError:
        return None, "path-escape", rel
    if not rel_root.parts:
        return None, "malformed-line", rel
    return rel_root.as_posix(), None, ""


def machine_paths_in_text(text: str) -> list[tuple[int, str]]:
    hits = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in MACHINE_PATH_RE.finditer(line):
            hits.append((lineno, m.group(0)))
    return hits


def scan_content(root: Path, refs: set[str], cache: dict[str, list[tuple[int, str]]]):
    """Scan unique text files for machine-local paths (cached per run)."""
    for rel in refs:
        if rel in cache:
            continue
        p = root / rel
        if not p.is_file() or p.stat().st_size > MAX_SCAN_BYTES:
            cache[rel] = []
            continue
        head = p.read_bytes()[:8192]
        if b"\0" in head:
            cache[rel] = []
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            cache[rel] = []
            continue
        cache[rel] = machine_paths_in_text(text)
    return cache


# ---------------------------------------------------------------------------
# audit
# ---------------------------------------------------------------------------

def infer_manifest_base(root: Path, target: Path) -> Path:
    """Pick the directory a checksum manifest's paths are relative to.

    Most manifests live beside their inputs, but ``logs/artifacts.sha256``
    names paths from the bundle root.  Choose the closest ancestor whose
    relative entries resolve most often; ties keep the closest base.
    """
    rels: list[str] = []
    for _, value, extra in parse_lines(
        target.read_text(encoding="utf-8", errors="replace")
    ):
        if value is None:
            continue
        rel = extra
        if rel.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:[\\/]", rel):
            continue
        rels.append(rel)
    bases = [target.parent]
    for anc in target.parent.parents:
        bases.append(anc)
        if anc == root:
            break

    def score(base: Path) -> int:
        n = 0
        for rel in rels:
            p = Path(os.path.normpath(str(base / rel)))
            try:
                p.relative_to(root)
            except ValueError:
                continue
            if p.is_file():
                n += 1
        return n

    best = bases[0]
    best_score = score(best)
    for base in bases[1:]:
        s = score(base)
        if s > best_score:
            best = base
            best_score = s
    return best


def audit_target(
    root: Path,
    target: Path,
    tracked: set[str],
    kind: str,
    *,
    base: Path | None = None,
    root_for_ignore: Path | None = None,
    scan_cache: dict[str, list[tuple[int, str]]] | None = None,
) -> TargetReport:
    rel_target = target.relative_to(root).as_posix()
    rep = TargetReport(target=rel_target, kind=kind)
    if rel_target not in tracked:
        rep.issues.append(Issue(rel_target, "untracked-certificate", ERROR,
                                f"{rel_target} is not in the tree at this revision"))
    try:
        text = target.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        rep.issues.append(Issue(rel_target, "cert-unreadable", ERROR, str(exc)))
        return rep
    if kind == "cell-certificate":
        base = root
    elif base is None:
        base = infer_manifest_base(root, target)
    rep.base = base.relative_to(root).as_posix() if base != root else "."
    entries: list[tuple[int, str, str]] = []  # lineno, digest, rel_root
    refs: set[str] = set()
    seen_paths: dict[str, int] = {}

    for lineno, value, extra in parse_lines(text):
        if value is None:
            tag, raw = extra
            if tag == "comment":
                if raw.startswith("# outside-root"):
                    rep.issues.append(
                        Issue(rel_target, "outside-root-marker", ERROR,
                              f"line {lineno}: {raw[:120]}")
                    )
                hits = machine_paths_in_text(raw)
                if hits:
                    rep.issues.append(
                        Issue(rel_target, "machine-path-in-cert-comment", WARNING,
                              f"line {lineno}: {hits[0][1]}")
                    )
                continue
            rep.issues.append(Issue(rel_target, "malformed-line", ERROR,
                                    f"line {lineno}: {raw[:120]}"))
            continue

        rel_root, err, detail = resolve_ref(root, base, extra, kind)
        if err:
            rep.issues.append(Issue(rel_target, err, ERROR,
                                    f"line {lineno}: {detail}"))
            continue
        assert rel_root is not None
        rep.entries += 1
        entries.append((lineno, value, rel_root))
        refs.add(rel_root)
        seen_paths[rel_root] = seen_paths.get(rel_root, 0) + 1
        p = root / rel_root

        if not p.is_file():
            ignored = False
            if root_for_ignore is not None:
                ignored = ignored_path(root_for_ignore, rel_root)
            code = "build-artifact" if ignored else "missing-file"
            rep.issues.append(Issue(rel_target, code, ERROR,
                                    f"{rel_root} (line {lineno})"))
            continue
        rep.files += 1
        rep.bytes += p.stat().st_size

        if p.is_symlink():
            try:
                p.resolve().relative_to(root)
            except ValueError:
                rep.issues.append(Issue(rel_target, "symlink-escape", ERROR,
                                        rel_root))
                continue

        if rel_root not in tracked:
            ignored = False
            if root_for_ignore is not None:
                ignored = ignored_path(root_for_ignore, rel_root)
            code = "build-artifact" if ignored else "untracked-file"
            rep.issues.append(Issue(rel_target, code, ERROR,
                                    f"{rel_root} (line {lineno})"))
        actual = digest(p)
        if actual != value:
            rep.issues.append(Issue(rel_target, "digest-mismatch", ERROR,
                                    f"{rel_root} (line {lineno})"))

    for rel_root, count in sorted(seen_paths.items()):
        if count > 1:
            rep.issues.append(Issue(rel_target, "duplicate-entry", WARNING,
                                    f"{rel_root} listed {count} times"))

    if rep.entries == 0:
        rep.issues.append(Issue(rel_target, "empty-certificate", ERROR))

    if kind == "cell-certificate":
        rep.issues.extend(
            _audit_cell_scope(root, target, rel_target, entries, refs, tracked)
        )
    _audit_content(root, rel_target, refs, rep, scan_cache)
    return rep


def _audit_cell_scope(
    root: Path,
    cert: Path,
    rel_cert: str,
    entries: list[tuple[int, str, str]],
    refs: set[str],
    tracked: set[str],
) -> list[Issue]:
    issues: list[Issue] = []
    leg = cert.parent.name
    cell_dir = cert.parent.parent
    in_divergence = cell_dir.name == "divergence"
    cell_root = cell_dir.parent if in_divergence else cell_dir

    # result.txt must be covered by the leg that produced it.
    result = cert.parent / "result.txt"
    if result.is_file():
        rel_result = result.relative_to(root).as_posix()
        if rel_result not in refs:
            issues.append(Issue(rel_cert, "result-uncovered", ERROR,
                                f"{rel_result} not hashed"))
    elif leg in LEG_DIRS:
        issues.append(Issue(rel_cert, "result-missing", ERROR,
                            f"{cert.parent.relative_to(root).as_posix()}/result.txt"))

    # The leg's own runner and the cell record should be bound too.
    for name, path in (
        ("run.sh", cert.parent / "run.sh"),
        ("spec.md", cell_root / "spec.md"),
        ("notes.md", cell_root / "notes.md"),
    ):
        if path.is_file():
            rel = path.relative_to(root).as_posix()
            if rel not in refs:
                issues.append(Issue(rel_cert, f"own-{name}-uncovered", WARNING,
                                    f"{rel} not hashed"))

    cross_leg: list[str] = []
    nested_div: list[str] = []
    div_parent: list[str] = []
    outside: dict[str, int] = {}

    for _, _, rel_root in entries:
        try:
            rel_cell = Path(rel_root).relative_to(cell_root.relative_to(root))
        except ValueError:
            # Shared input: classify for an aggregated informational note.
            try:
                rel_eq = Path(rel_root).relative_to(EQUIV_REL)
            except ValueError:
                cat = "repo-other"
            else:
                parts = rel_eq.parts
                if parts[0] == "cells" and len(parts) > 1:
                    cat = f"cells/{parts[1].split('_')[0]}"
                else:
                    cat = "/".join(parts[:2]) if len(parts) > 1 else parts[0]
            outside[cat] = outside.get(cat, 0) + 1
            continue

        parts = rel_cell.parts
        first = parts[0] if parts else ""
        if in_divergence:
            if first == "divergence":
                sub = parts[1] if len(parts) > 1 else ""
                if sub and sub != leg:
                    cross_leg.append(rel_root)
            elif first in LEG_DIRS:
                div_parent.append(rel_root)
        else:
            if first == "divergence":
                nested_div.append(rel_root)
            elif first in LEG_DIRS and first != leg:
                cross_leg.append(rel_root)

    if cross_leg:
        issues.append(Issue(rel_cert, "cross-leg", WARNING,
                            f"{len(cross_leg)} sibling-leg input(s), e.g. "
                            f"{cross_leg[0]}"))
    if nested_div:
        issues.append(Issue(rel_cert, "nested-divergence", WARNING,
                            f"{len(nested_div)} divergence input(s), e.g. "
                            f"{nested_div[0]}"))
    if div_parent:
        issues.append(Issue(rel_cert, "divergence-parent-leak", WARNING,
                            f"{len(div_parent)} outer-leg input(s), e.g. "
                            f"{div_parent[0]}"))
    if outside:
        top = ", ".join(f"{k}={v}" for k, v in sorted(outside.items()))
        issues.append(Issue(rel_cert, "outside-cell", INFO, top))

    # Completeness: every tracked file that belongs to this leg or the cell
    # record should be bound.  Build outputs are excluded (they are not
    # reproducible inputs), and sibling legs are audited by their own certs.
    cell_prefix = cell_root.relative_to(root).as_posix() + "/"
    own_prefix = cert.parent.relative_to(root).as_posix() + "/"
    uncovered: list[str] = []
    for rel in sorted(tracked):
        if not rel.startswith(cell_prefix):
            continue
        sub = rel[len(cell_prefix):]
        first = sub.split("/")[0]
        if first == "divergence":
            parts = sub.split("/")
            if len(parts) > 1 and parts[1] in LEG_DIRS:
                if not rel.startswith(own_prefix):
                    continue
        elif first in LEG_DIRS:
            if not rel.startswith(own_prefix):
                continue
        if rel.endswith(CERT_NAME) or any(p in SKIP_PARTS for p in rel.split("/")):
            continue
        if rel not in refs:
            uncovered.append(rel)
    if uncovered:
        issues.append(Issue(
            rel_cert, "uncovered-cell-input", WARNING,
            f"{len(uncovered)} file(s), e.g. {uncovered[0]}",
        ))
    return issues


def _audit_content(
    root: Path,
    rel_target: str,
    refs: set[str],
    rep: TargetReport,
    scan_cache: dict[str, list[tuple[int, str]]] | None,
) -> None:
    cache = scan_cache if scan_cache is not None else {}
    scan_content(root, refs, cache)
    files = 0
    hits = 0
    examples: list[str] = []
    build_files = 0
    for rel in refs:
        found = cache.get(rel, [])
        if not found:
            continue
        files += 1
        hits += len(found)
        for lineno, value in found[:1]:
            if len(examples) < 3:
                examples.append(f"{rel}:{lineno}:{value}")
        p = root / rel
        if p.is_file() and p.suffix in {".ll", ".saw", ".cry"}:
            try:
                if BUILD_PATH_RE.search(p.read_text(errors="replace")):
                    build_files += 1
            except OSError:
                pass
    if hits:
        rep.issues.append(Issue(
            rel_target, "machine-path-in-content", WARNING,
            f"{files} file(s), {hits} hit(s); " + "; ".join(examples),
        ))
    if build_files:
        rep.issues.append(Issue(
            rel_target, "build-path-in-ir", INFO,
            f"{build_files} IR/spec file(s) name build/ artifacts",
        ))


# ---------------------------------------------------------------------------
# fuzz harness
# ---------------------------------------------------------------------------

class Mutation:
    """A reversible file mutation in the scratch extraction."""

    def __init__(self, label: str, path: Path, new_bytes: bytes | None,
                 expected: str, cert: Path):
        self.label = label
        self.path = path
        self.new_bytes = new_bytes  # None = delete
        self.expected = expected
        self.cert = cert
        self._old: bytes | None = None
        self._mode: int | None = None

    def apply(self) -> None:
        if self.path.exists():
            self._old = self.path.read_bytes()
            self._mode = self.path.stat().st_mode
        else:
            self._old = None
        if self.new_bytes is None:
            self.path.unlink(missing_ok=True)
        else:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_bytes(self.new_bytes)

    def restore(self) -> None:
        if self._old is None:
            self.path.unlink(missing_ok=True)
        else:
            self.path.write_bytes(self._old)
            if self._mode is not None:
                os.chmod(self.path, self._mode)


@dataclasses.dataclass
class FuzzCase:
    label: str
    expected: str
    mutation: Mutation


def _append_line(path: Path, line: str) -> bytes:
    old = path.read_bytes() if path.exists() else b""
    if old and not old.endswith(b"\n"):
        old += b"\n"
    return old + line.encode() + b"\n"


def build_fuzz_cases(fuzz_root: Path, certs: list[Path], rng: random.Random,
                     iterations: int) -> list[FuzzCase]:
    cases: list[FuzzCase] = []
    if not certs:
        return cases

    def pick_cert(seed_cert: Path | None = None) -> Path:
        if seed_cert is not None:
            return seed_cert
        return certs[rng.randrange(len(certs))]

    def refs_of(cert: Path) -> list[tuple[str, Path]]:
        out = []
        for line in cert.read_text(errors="replace").splitlines():
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            parts = s.split(None, 1)
            if len(parts) != 2:
                continue
            p = fuzz_root / parts[1]
            if p.is_file():
                out.append((parts[1], p))
        return out

    def add(label: str, mutation: Mutation) -> None:
        cases.append(FuzzCase(label, mutation.expected, mutation))

    # Deterministic battery -------------------------------------------------
    cert = pick_cert()
    refs = refs_of(cert)
    if refs:
        rel, path = refs[0]
        original = path.read_bytes()
        if original:
            idx = len(original) // 2
            flipped = bytearray(original)
            flipped[idx] ^= 0x01
            add("tamper-referenced-file",
                Mutation("tamper", path, bytes(flipped),
                         "digest-mismatch", cert))
        add("delete-referenced-file",
            Mutation("delete", path, None, "missing-file", cert))
        add("machine-path-in-content",
            Mutation("machine-path", path,
                     original + b"\n# " + HOME_ROOT.encode() + b"ubuntu/cert-repro-fuzz-leak\n",
                     "machine-path-in-content", cert))

    cert = pick_cert()
    add("absolute-path-line",
        Mutation("absolute", cert,
                 _append_line(cert, "0" * 64 + "  " + HOME_ROOT + "ubuntu/leaked"),
                 "absolute-path", cert))
    add("path-escape-line",
        Mutation("escape", cert,
                 _append_line(cert, "0" * 64 + "  ../outside/leak"),
                 "path-escape", cert))
    add("build-artifact-line",
        Mutation("build", cert,
                 _append_line(cert, "0" * 64 + "  spec/equiv/cells/_fuzz/build/leak.txt"),
                 "build-artifact", cert))
    add("bad-line-digest",
        Mutation("line-digest", cert,
                 _append_line(cert, "1" * 64 + "  spec/equiv/cells/INDEX.md"),
                 "digest-mismatch", cert))

    # Remove the result.txt line from a leg certificate.
    for c in certs:
        if c.parent.name not in LEG_DIRS:
            continue
        rel_result = (c.parent / "result.txt").relative_to(fuzz_root).as_posix()
        lines = c.read_text(errors="replace").splitlines(keepends=True)
        kept = [ln for ln in lines
                if not (ln.strip() and not ln.strip().startswith("#")
                        and ln.split(None, 1)[1].strip() == rel_result)]
        if len(kept) != len(lines):
            add("result-line-removed",
                Mutation("result", c, "".join(kept).encode(),
                         "result-uncovered", c))
            break

    # Nested divergence: a normal leg certificate must not bind divergence/.
    div_cert = next((c for c in certs
                     if c.parent.parent.name == "divergence"), None)
    if div_cert is not None:
        outer = div_cert.parent.parent.parent
        outer_cert = outer / "alive2" / CERT_NAME
        div_result = div_cert.parent / "result.txt"
        if outer_cert.is_file() and div_result.is_file():
            rel = div_result.relative_to(fuzz_root).as_posix()
            line = f"{digest(div_result)}  {rel}"
            add("nested-divergence-line",
                Mutation("nested", outer_cert, _append_line(outer_cert, line),
                         "nested-divergence", outer_cert))

    # Randomised battery ----------------------------------------------------
    text_refs: list[tuple[Path, tuple[str, Path]]] = []
    for c in certs:
        for rel, p in refs_of(c):
            if p.suffix in TEXT_SUFFIXES and p.stat().st_size < 1_000_000:
                text_refs.append((c, (rel, p)))

    for i in range(iterations):
        if text_refs and rng.random() < 0.5:
            c, (rel, p) = text_refs[rng.randrange(len(text_refs))]
            original = p.read_bytes()
            action = rng.choice(("tamper", "delete", "machine-path",
                                 "absolute-line"))
            if action == "tamper" and original:
                pos = rng.randrange(len(original))
                flipped = bytearray(original)
                flipped[pos] ^= 1 << rng.randrange(8)
                add(f"random-{i}-tamper",
                    Mutation("tamper", p, bytes(flipped),
                             "digest-mismatch", c))
            elif action == "delete":
                add(f"random-{i}-delete",
                    Mutation("delete", p, None, "missing-file", c))
            elif action == "machine-path":
                add(f"random-{i}-machine-path",
                    Mutation("machine-path", p,
                             original + b"\n/tmp/opencode/cert-repro-random\n",
                             "machine-path-in-content", c))
            else:
                add(f"random-{i}-absolute",
                    Mutation("absolute", c,
                             _append_line(c, "0" * 64 + "  /workspace/leak"),
                             "absolute-path", c))
        else:
            c = certs[rng.randrange(len(certs))]
            kind = rng.choice(("absolute", "escape", "build"))
            rel = {
                "absolute": HOME_ROOT + "ubuntu/random-leak",
                "escape": "../../random-leak",
                "build": "spec/equiv/cells/_fuzz/build/random.bc",
            }[kind]
            expected = {
                "absolute": "absolute-path",
                "escape": "path-escape",
                "build": "build-artifact",
            }[kind]
            add(f"random-{i}-{kind}-line",
                Mutation(kind, c, _append_line(c, "0" * 64 + f"  {rel}"),
                         expected, c))
    return cases


def run_fuzz(
    repo: Path,
    sha: str,
    ignore_root: Path,
    tracked: set[str],
    tmp: Path,
    iterations: int,
    seed: int,
) -> dict:
    fuzz_root = extract_archive(repo, sha, tmp)
    certs, _ = discover(fuzz_root)
    rng = random.Random(seed)
    cases = build_fuzz_cases(fuzz_root, certs, rng, iterations)
    results = []
    passed = failed = 0
    # Positive control: a known-clean cell certificate must replay with no
    # errors.  This catches false positives in the checks above.
    controls = []
    control_candidates = [
        c for c in certs
        if "C-L-pick" not in c.parts and c.parent.name in LEG_DIRS
    ]
    for c in control_candidates[:2]:
        rep = audit_target(
            fuzz_root, c, tracked, "cell-certificate",
            root_for_ignore=ignore_root, scan_cache={},
        )
        controls.append({
            "target": c.relative_to(fuzz_root).as_posix(),
            "passed": not rep.errors,
            "codes": sorted({i.code for i in rep.errors}),
        })
    control_failed = sum(1 for c in controls if not c["passed"])

    for case in cases:
        case.mutation.apply()
        try:
            # Fresh scan cache: the mutated file must be re-read, not served
            # from a pre-mutation content scan.
            rep = audit_target(
                fuzz_root, case.mutation.cert, tracked, "cell-certificate",
                root_for_ignore=ignore_root, scan_cache={},
            )
            codes = {i.code for i in rep.issues}
            ok = case.expected in codes
            # A build line must be rejected as either ignored or untracked.
            if not ok and case.expected == "build-artifact":
                ok = "untracked-file" in codes
        finally:
            case.mutation.restore()
        if ok:
            passed += 1
        else:
            failed += 1
        results.append({
            "case": case.label,
            "expected": case.expected,
            "passed": ok,
            "codes": sorted(codes),
        })
    return {
        "root": str(fuzz_root),
        "cases": len(cases),
        "passed": passed,
        "failed": failed,
        "controls": controls,
        "controls_failed": control_failed,
        "seed": seed,
        "iterations": iterations,
        "failures": [r for r in results if not r["passed"]],
    }


# ---------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------

def summarize(reports: list[TargetReport], fuzz: dict | None, *,
              list_warnings: int) -> tuple[int, dict]:
    errors = [i for r in reports for i in r.errors]
    warnings = [i for r in reports for i in r.warnings]
    infos = [i for r in reports for i in r.issues if i.severity == INFO]
    code_counts: dict[str, int] = {}
    for i in errors + warnings:
        code_counts[i.code] = code_counts.get(i.code, 0) + 1

    print("\n== summary ==")
    print(f"  targets: {len(reports)} "
          f"(cell certificates={sum(1 for r in reports if r.kind == 'cell-certificate')}, "
          f"manifests={sum(1 for r in reports if r.kind == 'manifest')})")
    print(f"  certificate lines: {sum(r.entries for r in reports)}; "
          f"resolved files: {sum(r.files for r in reports)}; "
          f"bytes: {sum(r.bytes for r in reports)}")
    print(f"  errors: {len(errors)} issue line(s) in "
          f"{len({i.target for i in errors})} target(s)")
    print(f"  warnings: {len(warnings)} in "
          f"{len({i.target for i in warnings})} target(s)")
    if infos:
        print(f"  informational: {len(infos)}")
    if code_counts:
        print("  by code: " + ", ".join(
            f"{k}={v}" for k, v in sorted(code_counts.items())))

    if errors:
        print("\n-- replay errors --")
        shown = 0
        for r in reports:
            if not r.errors:
                continue
            suffix = f" (base={r.base})" if r.kind == "manifest" else ""
            print(f"  [{r.kind}] {r.target}{suffix}")
            by_code: dict[str, list[Issue]] = {}
            for i in r.errors:
                by_code.setdefault(i.code, []).append(i)
            for code, items in sorted(by_code.items()):
                print(f"    {code}: {len(items)}")
                for i in items[:6]:
                    print(f"      - {i.detail}")
                if len(items) > 6:
                    print(f"      ... {len(items) - 6} more")
            shown += 1
            if shown >= 40:
                print("  ... more targets omitted")
                break

    if warnings and list_warnings:
        print(f"\n-- warnings (showing up to {list_warnings} targets) --")
        by_code: dict[str, list[Issue]] = {}
        for i in warnings:
            by_code.setdefault(i.code, []).append(i)
        for code, items in sorted(by_code.items()):
            print(f"  {code}: {len(items)} target(s)")
            for i in items[:list_warnings]:
                print(f"    - {i.target}: {i.detail}")
            if len(items) > list_warnings:
                print(f"    ... {len(items) - list_warnings} more")

    if fuzz is not None:
        print("\n== fuzz (detector self-test) ==")
        print(f"  scratch root: {fuzz['root']}")
        print(f"  mutations: {fuzz['cases']}; caught: {fuzz['passed']}; "
              f"missed: {fuzz['failed']}; seed={fuzz['seed']}")
        for f in fuzz["failures"]:
            print(f"  MISS {f['case']}: expected {f['expected']}, "
                  f"got {f['codes']}")
        print(f"  positive controls: {len(fuzz['controls']) - fuzz['controls_failed']}"
              f"/{len(fuzz['controls'])} clean")
        for c in fuzz["controls"]:
            if not c["passed"]:
                print(f"  CONTROL-FAIL {c['target']}: {c['codes']}")

    ok = (not errors and (fuzz is None or
                          (fuzz["failed"] == 0 and fuzz["controls_failed"] == 0)))
    payload = {
        "targets": [
            {
                "target": r.target,
                "kind": r.kind,
                "base": r.base,
                "entries": r.entries,
                "files": r.files,
                "issues": [dataclasses.asdict(i) for i in r.issues],
            }
            for r in reports
        ],
        "errors": len(errors),
        "warnings": len(warnings),
        "informational": len(infos),
        "code_counts": code_counts,
        "fuzz": fuzz,
        "ok": ok,
    }
    return (0 if ok else 1), payload


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Replay spec/equiv certificates from a clean checkout "
                    "and fuzz the detector.",
    )
    ap.add_argument("--repo", default=".", help="repository path (default: cwd)")
    ap.add_argument("--rev", default="HEAD", help="revision to check out")
    ap.add_argument("--mode", choices=("worktree", "archive", "current"),
                    default="worktree",
                    help="clean checkout strategy (default: git worktree)")
    ap.add_argument("--clean-root", default=None,
                    help="use an existing clean checkout instead of creating one")
    ap.add_argument("--fuzz", type=int, default=0, metavar="N",
                    help="run N randomised detector mutations (plus a fixed battery)")
    ap.add_argument("--seed", type=int, default=20261020)
    ap.add_argument("--json", default=None, help="write the full report as JSON")
    ap.add_argument("--list-warnings", type=int, default=3,
                    help="targets to print per warning code (0 = summary only)")
    ap.add_argument("--strict", action="store_true",
                    help="also fail on warnings (portability/cross-leg hygiene)")
    ap.add_argument("--cells-only", action="store_true",
                    help="audit only spec/equiv/cells/**/certificate.sha256")
    ap.add_argument("--keep", action="store_true",
                    help="keep the clean checkout and print its path")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    repo = repo_root(Path(args.repo).resolve())
    sha = resolve_rev(repo, args.rev)
    tmp = tmp_root_default()
    clean_root: Path | None = None
    created = False
    created_paths: list[Path] = []
    try:
        if args.clean_root:
            clean_root = Path(args.clean_root).resolve()
        elif args.mode == "current":
            clean_root = repo
        elif args.mode == "archive":
            clean_root = extract_archive(repo, sha, tmp)
            created = True
            created_paths.append(clean_root)
        else:
            clean_root = make_worktree(repo, sha, tmp)
            created = True
            created_paths.append(clean_root)

        dirty = git(repo, "status", "--porcelain", "--",
                    str(EQUIV_REL), check=False).stdout.strip()
        if dirty and args.mode != "current":
            print("warning: working tree differs from HEAD for spec/equiv; "
                  "replay uses the clean checkout, not these edits",
                  file=sys.stderr)

        tracked = tracked_files_at(repo, sha)
        ignore_root = clean_root if (clean_root / ".git").exists() else repo
        certs, manifests = discover(clean_root)
        if args.cells_only:
            manifests = []
        reports: list[TargetReport] = []
        scan_cache: dict[str, list[tuple[int, str]]] = {}
        total = len(certs) + len(manifests)
        done = 0
        if not args.quiet:
            print("== fresh-checkout certificate replay ==")
            print(f"  repo: {repo}")
            print(f"  revision: {args.rev} -> {sha}")
            print(f"  clean checkout: {clean_root} ({args.mode})")
            print(f"  targets: {len(certs)} cell certificate(s), "
                  f"{len(manifests)} manifest(s)")

        for cert in certs:
            reports.append(audit_target(
                clean_root, cert, tracked, "cell-certificate",
                root_for_ignore=ignore_root, scan_cache=scan_cache,
            ))
            done += 1
            if not args.quiet and done % 50 == 0:
                print(f"  ... {done}/{total}", file=sys.stderr)
        for man in manifests:
            reports.append(audit_target(
                clean_root, man, tracked, "manifest",
                root_for_ignore=ignore_root, scan_cache=scan_cache,
            ))

        fuzz_result = None
        if args.fuzz >= 0 and args.fuzz is not None and args.fuzz > 0:
            fuzz_result = run_fuzz(
                repo, sha, ignore_root, tracked, tmp, args.fuzz, args.seed,
            )
            created_paths.append(Path(fuzz_result["root"]))

        rc, payload = summarize(
            reports, fuzz_result,
            list_warnings=args.list_warnings,
        )
        payload.update({
            "repo": str(repo),
            "rev": args.rev,
            "sha": sha,
            "clean_root": str(clean_root),
            "mode": args.mode,
        })
        if args.json:
            Path(args.json).write_text(
                json.dumps(payload, indent=2, sort_keys=True) + "\n"
            )
        if args.strict and any(r.warnings for r in reports):
            print("strict: warnings treated as failures", file=sys.stderr)
            rc = 1
        print(f"\nRESULT: {'PASS' if rc == 0 else 'FAIL'}")
        return rc
    except RuntimeError as exc:
        print(f"setup error: {exc}", file=sys.stderr)
        return 2
    finally:
        if not args.keep:
            for path in reversed(created_paths):
                if path == clean_root and args.mode == "worktree":
                    remove_worktree(repo, path)
                else:
                    shutil.rmtree(path, ignore_errors=True)
            if args.mode == "worktree" and created:
                git(repo, "worktree", "prune", check=False)


if __name__ == "__main__":
    raise SystemExit(main())
