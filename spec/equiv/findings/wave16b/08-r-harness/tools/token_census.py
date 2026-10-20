#!/usr/bin/env python3
"""Error-token census for the F-HARNESS-002 adapter.

rbitcoin has no typed `ScriptError`; the adapter maps its closed message
vocabulary (`ConsensusError::Script(String)`) to Core ordinals. This tool keeps
that map honest:

  1. extract every `ConsensusError::Script("…")` / `format!("…")` literal from
     the pinned source (test modules excluded),
  2. extract every token literal from `adapter/entry_r3.rs` (mapped_kind,
     kind_of, is_internal_token),
  3. verify each source token is classified exactly once:
        mapped  -> a Core ordinal
        internal-> result 3 (engine misuse / unreachable encoding error)
        gap     -> explicitly listed known ambiguity (UNKNOWN + finding)
     and that no mapped literal is stale (absent from the engine source).

`--strict` exits 1 on an unclassified token or a stale map entry. That is a
source-drift alarm: a re-pin must re-run this census and review new tokens.

Usage:
  python3 token_census.py [--rbtc DIR] [--adapter FILE] [--strict]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_RBTC = Path("/tmp/opencode/equiv-work/rbitcoin-clean")
DEFAULT_ADAPTER = HERE.parent / "adapter" / "entry_r3.rs"

# Tokens whose Core kind depends on tape state the engine does not report.
# Kept UNKNOWN on purpose; see README "remaining error-map gaps".
# Tokens that only exist in `#[cfg(test)]` code (checked by grep at the pin).
TEST_ONLY = {
    "scriptSig parse",      # eval_script_sig_pushes is #[cfg(test)]
    "scriptSig non-push",   # same helper
}

KNOWN_GAPS = {
    # empty signature or empty pubkey in a P2WPKH witness. Core runs the implied
    # P2PKH script: EVAL_FALSE (2) if the pubkey hashes to the program and the
    # signature is empty; EQUALVERIFY (12) if the (empty) pubkey does not hash.
    "p2wpkh empty witness item",
}

SRC_GLOBS = ["crates/rbitcoin-consensus/src/**/*.rs"]


def strip_tests(text: str) -> str:
    """Drop the trailing `#[cfg(test)] mod tests { … }` block."""
    matches = list(re.finditer(r"#\[cfg\(test\)\]\s*\n\s*mod \w+\b", text))
    return text[: matches[-1].start()] if matches else text


def source_tokens(rbtc: Path) -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}
    for glob in SRC_GLOBS:
        for path in sorted(rbtc.glob(glob)):
            name = path.name
            if name.startswith(("tests_", "core_")):
                continue  # cfg(test) fixture modules, not the engine boundary
            text = strip_tests(path.read_text())
            # ConsensusError::Script("literal" ...) and Script(format!("prefix{…}"))
            for m in re.finditer(
                r'ConsensusError::Script\(\s*(?:format!\(\s*)?"((?:[^"\\]|\\.)*)"',
                text,
            ):
                tok = m.group(1)
                if "{" in tok:
                    tok = tok.split("{", 1)[0]
                if not tok:
                    # `format!("{msg} txid=… vin=…")`: the annotation wrapper,
                    # not a token. The inner error is captured separately.
                    continue
                found.setdefault(tok, []).append(str(path.relative_to(rbtc)))
    return found


def adapter_tables(path: Path) -> tuple[dict[str, int], set[str], dict[str, int]]:
    text = path.read_text()
    start = text.index("fn mapped_kind")
    end = text.index("fn is_native_witness_v1_plus")
    region = text[start:end]

    mapped: dict[str, int] = {}
    # Arms can wrap across lines: "a" | "b"
    #                        | "c" => N,
    for m in re.finditer(
        r'((?:"[^"]*"\s*(?:\|\s*)?)+)\s*=>\s*(\d+)', region
    ):
        ordinal = int(m.group(2))
        for lit in re.findall(r'"([^"]*)"', m.group(1)):
            mapped[lit] = ordinal
    # context-sensitive arms handled by kind_of
    mapped["der sig"] = -1          # 24 if DERSIG else 2
    mapped["unknown opcode 0x6a"] = 3

    # Exact internal tokens, then prefix arms (dynamic opcode tokens).
    internal = set(re.findall(
        r'token == "([^"]+)"',
        region[region.index("fn is_internal_token"):],
    ))
    prefixes: dict[str, int] = {}
    for lit in re.findall(r'token\.starts_with\("([^"]+)"\)', region):
        if lit.startswith("disabled opcode"):
            prefixes[lit] = 17
        elif lit.startswith("unknown opcode"):
            prefixes[lit] = 16
        else:
            internal.add(lit)
    return mapped, internal, prefixes


def classify(tok: str, mapped: dict[str, int], internal: set[str],
             prefixes: dict[str, int]) -> tuple[str, object]:
    if tok in mapped:
        return "mapped", mapped[tok]
    if tok in internal:
        return "internal", 3
    for p in internal:
        # dynamic internal tokens ("tapscript sighash prevouts", …)
        if tok.startswith(p):
            return "internal", 3
    for p, ordinal in prefixes.items():
        if tok.startswith(p):
            return "mapped-dynamic", ordinal
    if tok in TEST_ONLY:
        return "test-only", None
    if tok in KNOWN_GAPS:
        return "gap", None
    return "UNCLASSIFIED", None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rbtc", default=str(DEFAULT_RBTC))
    ap.add_argument("--adapter", default=str(DEFAULT_ADAPTER))
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    rbtc = Path(args.rbtc)
    src = source_tokens(rbtc)
    mapped, internal, prefixes = adapter_tables(Path(args.adapter))

    print(f"rbitcoin source: {rbtc}")
    print(f"adapter:         {args.adapter}")
    print(f"source tokens:   {len(src)}")
    print(f"adapter literals:{len(mapped)} mapped, {len(internal)} internal\n")

    rows = []
    unclassified = []
    for tok in sorted(src):
        kind, ordinal = classify(tok, mapped, internal, prefixes)
        rows.append((tok, kind, ordinal, len(src[tok])))
        if kind == "UNCLASSIFIED":
            unclassified.append(tok)

    width = max(len(t) for t, *_ in rows) if rows else 10
    for tok, kind, ordinal, n in rows:
        val = "" if ordinal is None else str(ordinal)
        print(f"  {tok:{width}s}  {kind:15s} {val:>3s}  x{n}")

    used = set(src)
    stale = sorted(lit for lit in mapped if lit not in used
                   and lit not in {"unknown opcode 0x6a", "der sig"})
    print("\nstale mapped literals (in adapter, not in engine source):")
    print("  " + (", ".join(stale) if stale else "none"))
    print("\nunclassified source tokens (would return EQUIV_ERR_UNKNOWN_ERROR):")
    print("  " + (", ".join(unclassified) if unclassified else "none"))

    counts: dict[str, int] = {}
    for _, kind, _, _ in rows:
        counts[kind] = counts.get(kind, 0) + 1
    print("\nclassification counts: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))

    if args.strict and (unclassified or stale):
        print("\nCENSUS_FAIL")
        return 1
    print("\nCENSUS_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
