# Notes — `e3-cms/C-L-w32-cms-loop`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **rows:** SCR-116 and SCR-117 (both `full` inside the cell model)
- **result:** Alive2 `--bidirectional` green (1/1 function, symbolic
  `0 ≤ nSigs ≤ nKeys ≤ 20`, symbolic flags and salt); SAW green
  (120/120 proofs, 60 scenarios × 2 legs).
- **patches:** none.

## Reproduce

From the repo root:

```sh
spec/equiv/cells/e3-cms/C-L-w32-cms-loop/alive2/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-loop/saw/run.sh
sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-loop/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-loop/saw/certificate.sha256
```

`--smt-to=600000` is the runner default, and the runner extracts the cell
function with `llvm-extract --keep-const-init` (without it the low-S
half-order table becomes an external declaration and Alive2 reports a
spurious counterexample). Both legs are compiled at -O2 for
the Alive2 lane (SAW stays at -O0). At -O1 Alive2 v20.0 does not unroll the
bounded loops tagged `llvm.loop.unroll.disable` and produced a vacuous green
for this cell (measured with a mutant); -O2 emits the loops unrollable and
the loop mutant is caught. See `findings/wave32/20-cms-114-117/report.md`
§2/§4.

## Design

The cell is `interpreter.cpp:1163-1225` — the matching loop, the encoding
gates, the counters, the early exit and the tail. The observable includes
`fSuccess`, an early flag, both remaining counters and both indices, so
pair order and every increment are visible.

**No uninterpreted call.** Alive2 does not correlate two calls to the same
external declaration by argument (verified: `ext(x)+ext(x)` vs `2*ext(x)` is
reported non-equivalent). Both legs therefore call one concrete
deterministic predicate `e32_check_pair(sig, pk, salt)`. That makes the
verdict depend on the pair read at that position and keeps a mis-ordered
read observable. The claim is control flow plus encoding precedence given a
shared verdict function, not ECDSA.

Element contents come from a fixed vocabulary selected by
`(position + salt) mod 5` for signatures (empty, valid DER/hashtype 1,
invalid DER, high-S, hashtype 0) and `(position + salt) mod 3` for pubkeys
(compressed, uncompressed, bad prefix). All five encoding gates are
represented, including at iterations 2 and 3.

## Mutation

Swapping the key-encoding check ahead of the signature-encoding check is
caught by Alive2/SAW (a pair that is invalid in both ways must report the
signature ordinal). See `findings/wave32/20-cms-114-117/report.md` §4.

## Tools

clang/LLVM 20.1.2, alive-tv v20.0, SAW 1.6 (`68eed5f release-1.6`),
Z3 4.8.12.
