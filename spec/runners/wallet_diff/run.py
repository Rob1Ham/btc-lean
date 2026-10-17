#!/usr/bin/env python3
"""Command-line entry point for the wallet differential harness.

Modes
-----
``--emit``
    Start a private regtest daemon, run every scenario, and rewrite
    ``spec/data/wallet/cases.jsonl`` plus a small manifest.
``--replay``
    Start a fresh daemon, re-run every scenario, and compare each regenerated
    case with the recorded corpus.
``--smoke``
    Start a fresh daemon, run ten representative cases, and shut down.  This
    exercises the driver and the main RPC paths without touching the corpus.
``--compare-json PATH``
    Compare a Lean-side JSON file with the corpus.  This mode does not need a
    running daemon unless it is combined with one of the modes above.

The command is intentionally dependency-free and does not read wallet keys
from the environment; all key material is the fixed test key in scenarios.py.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from bitcoind import DEFAULT_BITCOIND, Bitcoind, RPCError
import scenarios

SPEC_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CASES = SPEC_ROOT / "data" / "wallet" / "cases.jsonl"
DEFAULT_MANIFEST = SPEC_ROOT / "data" / "wallet" / "manifest.json"


# --------------------------------------------------------------------------
# Serialization
# --------------------------------------------------------------------------


def canonical_json(case: dict[str, Any]) -> str:
    """Serialize one case as a stable, compact JSON line."""
    return json.dumps(case, sort_keys=True, separators=(",", ":"))


def write_corpus(path: Path, cases: list[dict[str, Any]]) -> str:
    """Write JSONL and return the SHA-256 of the exact bytes written."""
    payload = "".join(canonical_json(case) + "\n" for case in cases)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(payload, encoding="utf-8")
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def read_corpus(path: Path) -> list[dict[str, Any]]:
    """Read JSONL cases, rejecting duplicate ids."""
    cases: list[dict[str, Any]] = []
    seen: set[str] = set()
    with path.open(encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                case = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{lineno}: invalid JSON: {exc}") from exc
            if "id" not in case:
                raise ValueError(f"{path}:{lineno}: missing id")
            if case["id"] in seen:
                raise ValueError(f"{path}:{lineno}: duplicate id {case['id']!r}")
            seen.add(case["id"])
            cases.append(case)
    return cases


# --------------------------------------------------------------------------
# Comparison
# --------------------------------------------------------------------------


def _diff(expected: Any, actual: Any, label: str) -> str:
    """Return a readable unified diff between two JSON values."""
    left = json.dumps(expected, sort_keys=True, indent=2, ensure_ascii=False).splitlines()
    right = json.dumps(actual, sort_keys=True, indent=2, ensure_ascii=False).splitlines()
    return "\n".join(
        difflib.unified_diff(left, right, fromfile=f"corpus:{label}", tofile=f"actual:{label}", lineterm="")
    )


def compare_case_sets(
    expected: dict[str, dict[str, Any]],
    actual: dict[str, dict[str, Any]],
    *,
    allow_partial: bool = False,
) -> tuple[int, list[str]]:
    """Compare two id-keyed case dictionaries.

    Returns ``(mismatch_count, messages)``.  Missing actual cases are failures
    unless ``allow_partial`` is true; extra actual cases are always reported.
    """
    messages: list[str] = []
    mismatches = 0
    for cid in sorted(expected):
        if cid not in actual:
            if not allow_partial:
                mismatches += 1
                messages.append(f"missing: {cid}")
            continue
        want = expected[cid]
        got = actual[cid]
        for field in ("kind", "method", "params", "wallet", "expect"):
            if field in want or field in got:
                if want.get(field) != got.get(field):
                    mismatches += 1
                    messages.append(f"mismatch: {cid} field={field}\n" + _diff(want.get(field), got.get(field), cid))
                    break
    for cid in sorted(set(actual) - set(expected)):
        mismatches += 1
        messages.append(f"unexpected: {cid}")
    return mismatches, messages


def filter_prefix(cases: dict[str, dict[str, Any]], prefix: str | None) -> dict[str, dict[str, Any]]:
    """Filter a case dictionary by id prefix."""
    if not prefix:
        return cases
    return {cid: case for cid, case in cases.items() if cid.startswith(prefix)}


# --------------------------------------------------------------------------
# Lean-side JSON
# --------------------------------------------------------------------------


def load_lean_json(path: Path) -> dict[str, Any]:
    """Load a Lean-side result file as ``{id: expected}``.

    Accepted shapes::

        [{"id": "...", "result": ...}, ...]
        [{"id": "...", "error": {"code": ..., "message": "..."}}, ...]
        [{"id": "...", "expect": ...}, ...]
        {"id": ..., "result": ...}          # one case
        {"case.id": result, ...}            # mapping
    """
    data = json.loads(path.read_text(encoding="utf-8"))
    out: dict[str, Any] = {}

    def add(cid: str, value: Any) -> None:
        if cid in out:
            raise ValueError(f"duplicate id in {path}: {cid}")
        out[cid] = value

    if isinstance(data, list):
        for item in data:
            if not isinstance(item, dict) or "id" not in item:
                raise ValueError(f"{path}: every list entry needs an id")
            cid = str(item["id"])
            if "result" in item:
                add(cid, {"result": item["result"]})
            elif "error" in item:
                add(cid, {"error": item["error"]})
            elif "expect" in item:
                add(cid, item["expect"])
            else:
                payload = {key: value for key, value in item.items() if key != "id"}
                add(cid, {"result": payload})
    elif isinstance(data, dict):
        if "id" in data and ("result" in data or "error" in data or "expect" in data):
            cid = str(data["id"])
            if "result" in data:
                add(cid, {"result": data["result"]})
            elif "error" in data:
                add(cid, {"error": data["error"]})
            else:
                add(cid, data["expect"])
        else:
            for cid, value in data.items():
                if isinstance(value, dict) and set(value) <= {"result", "error", "expect"}:
                    add(str(cid), value)
                else:
                    add(str(cid), {"result": value})
    else:
        raise ValueError(f"{path}: expected a JSON object or array")
    return out


# --------------------------------------------------------------------------
# Modes
# --------------------------------------------------------------------------


def _pinned_version(binary: str) -> str:
    """Return the first line's version token from ``bitcoind --version``."""
    proc = subprocess.run([binary, "--version"], capture_output=True, text=True, check=False)
    first = (proc.stdout or proc.stderr).splitlines()[0] if (proc.stdout or proc.stderr) else ""
    match = re.search(r"version\s+(\S+)", first)
    return match.group(1) if match else "unknown"


def emit(node: Bitcoind, cases_path: Path, manifest_path: Path) -> int:
    """Run all scenarios, write the corpus, and print a summary."""
    cases = scenarios.run_all(node)
    digest = write_corpus(cases_path, cases)
    version_text = _pinned_version(node.binary)
    commit_match = re.search(r"-([0-9a-f]{8,40})$", version_text)
    commit = commit_match.group(1) if commit_match else "unknown"
    manifest = {
        "format": "wallet-diff-jsonl-v1",
        "bitcoind_version": version_text,
        "core_commit": commit,
        "case_count": len(cases),
        "rpc_case_count": sum(1 for case in cases if case.get("kind") == "rpc"),
        "check_case_count": sum(1 for case in cases if case.get("kind") == "check"),
        "sha256_cases": digest,
        "generator": "spec/runners/wallet_diff/run.py --emit",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"emit: wrote {len(cases)} cases to {cases_path}")
    print(f"emit: sha256 {digest}")
    print(f"emit: manifest {manifest_path}")
    return 0


def replay(node: Bitcoind, cases_path: Path, allow_partial: bool) -> int:
    """Re-run scenarios and compare them with the recorded corpus."""
    expected_cases = read_corpus(cases_path)
    expected = {case["id"]: case for case in expected_cases}
    actual_cases = scenarios.run_all(node)
    actual = {case["id"]: case for case in actual_cases}
    mismatches, messages = compare_case_sets(expected, actual, allow_partial=allow_partial)
    if mismatches:
        print(f"replay: FAIL, {mismatches} problem(s)")
        for message in messages[:20]:
            print(message)
        if len(messages) > 20:
            print(f"... {len(messages) - 20} more")
        return 1
    print(f"replay: OK, {len(expected)}/{len(expected)} cases match")
    return 0


def smoke(node: Bitcoind) -> int:
    """Run and print ten representative cases."""
    cases = scenarios.run_smoke(node)
    for case in cases:
        expectation = case.get("expect", {})
        status = "error" if "error" in expectation else "ok"
        print(f"smoke: {case['id']} ({case['kind']}, {status})")
    if len(cases) != 10:
        print(f"smoke: expected 10 cases, got {len(cases)}")
        return 1
    print("smoke: 10/10 cases recorded")
    return 0


def compare_json(cases_path: Path, lean_path: Path, only: str | None, allow_partial: bool) -> int:
    """Compare a Lean-side JSON file against the corpus."""
    corpus = {case["id"]: case for case in read_corpus(cases_path)}
    corpus = filter_prefix(corpus, only)

    def normalize_expect(value: Any) -> dict[str, Any]:
        """Wrap check booleans so every expectation has result/error shape."""
        return value if isinstance(value, dict) else {"result": value}

    expected = {cid: normalize_expect(case["expect"]) for cid, case in corpus.items()}
    actual = filter_prefix(load_lean_json(lean_path), only)
    mismatches, messages = compare_case_sets(
        {cid: {"expect": value} for cid, value in expected.items()},
        {cid: {"expect": value} for cid, value in actual.items()},
        allow_partial=allow_partial,
    )
    if mismatches:
        print(f"compare-json: FAIL, {mismatches} problem(s)")
        for message in messages[:20]:
            print(message)
        if len(messages) > 20:
            print(f"... {len(messages) - 20} more")
        return 1
    if allow_partial:
        print(f"compare-json: OK, {len(actual)}/{len(expected)} case(s) compared (partial)")
    else:
        print(f"compare-json: OK, {len(expected)} case(s) compared")
    return 0


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--emit", action="store_true", help="regenerate the corpus")
    parser.add_argument("--replay", action="store_true", help="verify the corpus against a live bitcoind")
    parser.add_argument("--smoke", action="store_true", help="run ten representative cases")
    parser.add_argument("--compare-json", metavar="PATH", help="compare Lean-side JSON with the corpus")
    parser.add_argument("--cases", default=str(DEFAULT_CASES), help="corpus path (default: %(default)s)")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST), help="manifest path for --emit")
    parser.add_argument("--bitcoind", default=DEFAULT_BITCOIND, help="bitcoind binary (default: %(default)s)")
    parser.add_argument("--datadir", default=None, help="explicit datadir instead of a fresh temporary one")
    parser.add_argument("--keep", action="store_true", help="keep the temporary datadir for inspection")
    parser.add_argument("--only", default=None, help="restrict --compare-json to an id prefix")
    parser.add_argument("--allow-partial", action="store_true", help="do not fail when Lean output omits cases")
    parser.add_argument("--verbose", action="store_true", help="print the chosen datadir and RPC endpoint")
    return parser


def main(argv: list[str] | None = None) -> int:
    """Dispatch the requested mode and guarantee daemon cleanup."""
    parser = build_parser()
    args = parser.parse_args(argv)
    if not (args.emit or args.replay or args.smoke or args.compare_json):
        parser.print_help()
        return 2

    cases_path = Path(args.cases)
    needs_node = args.emit or args.replay or args.smoke
    if not needs_node:
        return compare_json(cases_path, Path(args.compare_json), args.only, args.allow_partial)

    node = Bitcoind(binary=args.bitcoind, datadir=args.datadir)
    try:
        node.start()
        if args.verbose:
            print(f"bitcoind: {args.bitcoind}")
            print(f"datadir: {node.datadir}")
            print(f"rpc: 127.0.0.1:{node.port}")
        rc = 0
        if args.emit:
            rc = emit(node, cases_path, Path(args.manifest))
        if args.replay:
            rc = max(rc, replay(node, cases_path, args.allow_partial))
        if args.smoke:
            rc = max(rc, smoke(node))
        if args.compare_json:
            rc = max(rc, compare_json(cases_path, Path(args.compare_json), args.only, args.allow_partial))
        return rc
    except (RPCError, OSError, RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    finally:
        if args.keep:
            node.cleanup(keep=True)
            print(f"kept datadir: {node.datadir}")
        else:
            node.cleanup(keep=False)


if __name__ == "__main__":
    sys.exit(main())
