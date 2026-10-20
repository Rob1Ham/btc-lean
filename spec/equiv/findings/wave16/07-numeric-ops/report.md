# Wave-16 · `07-numeric-ops`

Bounded C-vs-L both-tool cells for the numeric SCR rows **SCR-087 … SCR-092**.

- Branch: `wave16/07-numeric-ops` (local only, no push)
- Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- Base repo head when the cells were built: `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- Contract: v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- Tools: `alive-tv` (Ubuntu LLVM 20.1.2), `saw` 1.6, `clang++-20`
- Patches: **none** (`patches: none` in every cell)

## Result

| cell | rows | Alive2 | SAW | status |
|---|---|---|---|---|
| `numeric/C-L-unary-4byte` | SCR-087 | 6/6 correct | 12/12 proved | both-green |
| `numeric/C-L-binary-4byte` | SCR-088, SCR-090 | 13/13 correct | 26/26 proved | both-green |
| `numeric/C-L-within-4byte` | SCR-089 | 1/1 correct | 2/2 proved | both-green |
| `numeric/C-L-equal-rawbytes` | SCR-091 | 2/2 correct | 4/4 proved | both-green |
| `numeric/C-L-2div-disabled` | SCR-092 | 1/1 correct | 3/3 proved | both-green |

All ten certificates verify from the repository root (22 files each):

```sh
for c in spec/equiv/cells/numeric/*/; do
  for t in alive2 saw; do sha256sum -c "$c$t/certificate.sha256" || echo "BAD $c$t"; done
done
# 10/10 rc=0
```

## Row dispositions

| row | disposition | evidence / exact remaining gap |
|---|---|---|
| SCR-087 | **full** | all six opcodes; each over the whole length domain 0..7 (every 4-byte operand, content symbolic over 2^32, plus the width-cap reject at 5..7). `C-L-unary-4byte`. |
| SCR-088 | **full** | all 12 pushing wires (0x93, 0x94, 0x9a-0x9c, 0x9e-0xa4) plus `OP_NUMEQUALVERIFY`'s success arm (both operands dropped → empty-stack `EVAL_FALSE`), which the row note listed as unproved. `C-L-binary-4byte`. |
| SCR-089 | **full** (was partial via `e2-numeric/within-boundary`) | `C-L-within-4byte` covers x/min/max over every content word and length 0..7. The one-byte result is *extended*, not duplicated; stack underflow stays SCR-078's row. |
| SCR-090 | **full** | false ⇒ error 15 (NUMEQUALVERIFY), no stack; true arm ⇒ empty-stack `EVAL_FALSE`. Every operand pair in the 4-byte domain. `C-L-binary-4byte`. |
| SCR-091 | **full** | both wires, every element pair (2^64 content each) and every length 0..8, including length mismatch and the empty element; no CScriptNum decode is reachable. `C-L-equal-rawbytes`. |
| SCR-092 | **partial** | C-vs-L: the EvalScript wire gate for every 32-bit wire word (decides 0x8e in BASE and WITNESS_V0). C-vs-model only: the tapscript `OP_SUCCESS142` pre-pass. **Exact gap:** the twin has no tapscript engine (`twin/generator.md:409`, E4), so `ExecuteWitnessScript`'s pre-pass has no L counterpart; add it to the twin and compare against `cell_tap_scan`. Nothing is claimed as C-vs-L for tapscript. |

SCR-092 is deliberately **not** called full: the row's third clause (tapscript
treats 0x8e as OP_SUCCESS142) is proved against the independent model on the
Core excerpt, not against the twin, because the twin returns
`TWIN_INVALID_UNSUPPORTED` for tapscript before any opcode runs.

## The 0x8e / OP_2DIV result

`interpreter.cpp:471-489` is a plain disjunction, not a sigversion-guarded
branch: EvalScript rejects any of the 15 disabled wires in every sigversion it
executes, and it does so *before* the opcode switch, so 0x8e can never reach
the `OP_EQUAL` block where the `case OP_NOTEQUAL` is commented out. The
tapscript difference is entirely due to `ExecuteWitnessScript`'s pre-pass
(`interpreter.cpp:1841-1862`): `IsOpSuccess(0x8e)` is true (OP_SUCCESS142), the
pre-pass calls `set_success` and EvalScript never runs. Every disabled wire is
also an OP_SUCCESS wire, so the two facts compose without contradiction. The
cell's independent model (`tools/num.cry`: `disabledWire`, `opSuccessWire`,
`pGate`, `pTapScan`) encodes all three sets directly from Core and the Lean
`Defs.lean:455-492` definitions; both legs were proved against it.

## Model bug found (SCR-091) — the third leg earned its keep

The first SAW run of `C-L-equal-rawbytes` failed with a counterexample at
`la = lb = 1` whose *padding* bytes differed. C and L both compared only the
first byte and reported equality; `tools/num.cry:equalRaw` compared **all
eight** bytes regardless of length and reported inequality. The legs were
right, the model was wrong. `equalRaw` now guards each byte with `La < k || …`,
which is exactly Core's length-then-bytes `valtype` comparison. Two
implementations of the same source agreeing would not have exposed this; the
independent model did.

## Tool findings (feed back to the wave)

1. **Alive2 v20 + any `alloca` = quantified UB query.** A bounded copy of
   `CScriptNum::serialize` that keeps `out[n++]`/`out[n-1]` leaves a
   variable-index scratch array that SROA cannot remove; Alive2 then quantifies
   over 63-bit block addresses and times out. `encode_num`/`push_num` assemble
   the same bytes in a constant-indexed little-endian `uint64`. After the
   post-extract `opt -passes='default<O2>'` (applied identically to both legs),
   `grep -c alloca build/*_cell_*.ll` is 0 in all five cells.
2. **`llvm.abs` and `llvm.{smin,smax,umin,umax}` are unmodelled** (modules that
   both contain `abs` are reported as miscompiles; min/max are not reduced).
   `tools/expand_abs.py` expands them to their own definitions, poison-faithful
   for `abs`, and fails if any survives. It now also matches calls that carry
   parameter attributes (`noundef`, `range(i32 0, 16)`), which is what a
   `umax`/`umin` from `min(l & 15, 8)` looks like after `-O2`.
3. **`OP_ADD`/`OP_SUB` need `--smt-to=600000`** (default 120 s is not enough;
   ~2–3 min each). The binary cell exports `SMT_TO=600000`; the other cells use
   the default.
4. **SAW 1.6: use `z3`, not `abc`.** `abc` never finished `cell_1sub`; `z3`
   proves it in ~5 s. Cryptol literal width comes from the digit count (write
   16 hex digits for `[64]`), `!` does not exist (use `~`), and `||` binds
   *tighter* than `==`, so every chained comparison needs parentheses.
5. **`mk_leaf` treats an empty op set as "all handlers"**, and that full header
   does not compile standalone. `C-L-2div-disabled` therefore selects
   `OP_EQUAL` (unused) just to get a minimal header.
6. `src/build.sh` now reads an optional `LFNS` from `build.cfg` (C-leg-only
   entry points), so `cell_tap_scan` has no L counterpart without faking one.

## SCR-089 vs `cells/e2-numeric/within-boundary`

`e2-numeric/within-boundary` is a one-byte cell (2^24 triples) with a 2-byte
leaf; its own record says it does not exercise 2–4 byte operands or the width
cap. `numeric/C-L-within-4byte` re-derives the rule over the full 4-byte domain
plus the 5..7 reject edge, so the row's gap is closed rather than restated. The
e2 cell and its certificate were left untouched.

## Pre-existing issue outside this task's scope

`spec/equiv/cells/e2-numeric/within-boundary/saw/certificate.sha256` at HEAD
already disagrees with HEAD's tree: commit `805c804` changed
`cells/_tools/mk_leaf.py` and the e2 `build/build.txt` hash without
regenerating that certificate, so `sha256sum -c` fails on that one file even in
a clean checkout. This task did not modify the e2 cell — an accidental
regeneration of that certificate during development was reverted, which is why
the file is absent from the commit below. It needs an owner in the wave.

## Changes

- New: `spec/equiv/cells/numeric/{C-L-unary-4byte,C-L-binary-4byte,C-L-within-4byte,C-L-equal-rawbytes,C-L-2div-disabled}/`
  (`spec.md`, `notes.md`, `src/`, `alive2/`, `saw/` with raw `result.txt` and
  `certificate.sha256`).
- New: `spec/equiv/findings/wave16/07-numeric-ops/tools/` — shared cell
  tooling (`mk_num_leaf.py`, `num_common.h`, `num_core.h`, `num.cry`,
  `expand_abs.py`, `run_alive2.sh`, `run_saw.sh`, `certify.sh`) and this
  report.
- Not touched: `spec/db/equiv-cells.yaml`, `spec/equiv/results/**`,
  `docs/STATE.md`, `PINS.lock`, `contract/**`, `twin/**`, `shims/**`, the e2
  cell, any Core source. No row is flipped in the ledger by this commit; the
  dispositions above are for the wave orchestrator to apply.

## Reproduction

```sh
cd <repo>
bash spec/equiv/cells/numeric/C-L-unary-4byte/alive2/run.sh
bash spec/equiv/cells/numeric/C-L-unary-4byte/saw/run.sh
# ... same for the other four cells (each runner rebuilds, re-proves, re-certifies)
sha256sum -c spec/equiv/cells/numeric/*/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/*/saw/certificate.sha256
```

Each runner rebuilds from `src/` and `tools/`, so a fresh checkout reproduces
the raw results; `build/` is gitignored and excluded from the certificates.
