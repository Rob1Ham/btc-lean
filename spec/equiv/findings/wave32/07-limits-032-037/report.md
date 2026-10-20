# Wave 32 — task 07: limits SCR-032..SCR-037

**Worktree:** `/tmp/opencode/wave32/07-limits-032-037`
**Branch:** `wave32/07-limits-032-037`
**Base:** `805c804`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Lean model rev:** `4d62a97e551082a69b13f495365bff0a903b0c99`

## Result

Five of the six assigned rows are closed by new `both-green` cells.  SCR-036
is blocked by an ABI/domain bound, with the exact missing input and the
smallest next experiment recorded below.  No row is relabelled: the four cells
are new, and every green below has raw Alive2 and SAW output plus a
certificate that verifies from the repository root.

| SCR | status | cell | proved | remains | blocker |
|---|---|---|---|---|---|
| SCR-032 | **full** | `limits/C-L-w32-sigop-count` | `GetSigOpCount(false)`: CHECKSIG/CHECKSIGVERIFY = 1; CHECKMULTISIG/CHECKMULTISIGVERIFY = 20 at every site, push and non-push contexts, malformed tails; C ≡ L and both ≡ Cryptol | nothing in the row; domain is scripts ≤ 4 bytes (out-of-domain sentinel proved identical but outside the claim) | — |
| SCR-033 | **full** | `limits/C-L-w32-sigop-count` | `GetSigOpCount(true)`: accurate lookback over every preceding OP_1..OP_16 value, else 20, at every site; all wire contexts | nothing in the row; same 4-byte domain note | — |
| SCR-034 | **full** | `limits/C-L-w32-p2sh-scriptsig` | P2SH scriptSig arm: malformed/truncated ⇒ 0; any opcode > OP_16 ⇒ 0; empty ⇒ 0; else accurate count of the final push data's valid prefix, including OP_0/OP_N/OP_RESERVED clearing the data register and PUSHDATA1/2 last pushes | nothing in the row; the P2SH scriptPubKey test and tx/coin loop are outside the slice (documented) | — |
| SCR-035 | **full** | `limits/C-L-w32-witness-sigops` | `WitnessSigOps`: v0-20 ⇒ 1; v0-32 + non-empty stack ⇒ accurate count of the last item; v0-32 + empty stack ⇒ 0; v1+ ⇒ 0; other program lengths ⇒ 0 | nothing in the row; witness-script domain is ≤ 4 bytes | — |
| SCR-036 | **blocked** | — | nothing claimed | the P2SH-wrapped witness-program arm of `CountWitnessSigOps`: parse a push-only scriptSig, take its last push `d`, require `IsWitnessProgram(d)`, then `WitnessSigOps` on it | a non-zero result needs `d` of 22 or 34 bytes (v0-20/v0-32), hence a scriptSig of at least 23/35 bytes.  The limits ABI packs 64 bits and the cell domain is 4 bytes, so this arm is not representable.  Smallest next experiment: widen the limits ABI to 5 × uint64 (40 bytes) or pass the last push as a separate `(word vector, length)` with a decoded-push-list harness, keep the same unrolled parser, and raise the Alive2 SMT budget; see below. |
| SCR-037 | **full** | `limits/C-L-w32-sigop-cost` | weight-unit aggregation: `4*legacy` always; coinbase early return; P2SH term ×4 only under the P2SH flag; witness term ×1; C ≡ L and both ≡ Cryptol over all five 32-bit inputs | nothing in the row; the three counts are inputs by composition (the producing cells are named in the spec) | — |

## Cells

All cells live under `spec/equiv/cells/limits/` and use the shared harness
`spec/equiv/cells/_tools/limits/`.

| cell | entry point(s) | Alive2 | SAW | scripts |
|---|---|---|---|---|
| `C-L-w32-sigop-count` | `cell_sigop_accurate`, `cell_sigop_inaccurate` | 2/2 function pairs green | 4/4 proofs | `scripts ≤ 4 B` |
| `C-L-w32-p2sh-scriptsig` | `cell_p2sh_sigops` | 1/1 | 2/2 | `scriptSig ≤ 4 B` |
| `C-L-w32-witness-sigops` | `cell_witness_sigops` | 1/1 | 2/2 | `witness item ≤ 4 B` |
| `C-L-w32-sigop-cost` | `cell_sigop_cost` | 1/1 | 2/2 | counts are 32-bit inputs |

Each cell has `spec.md`, `notes.md`, `src/` (C leg, L leg, Cryptol spec, SAW
script, build wrapper), `alive2/{run.sh,result.txt,certificate.sha256}`, and
`saw/{run.sh,result.txt,certificate.sha256}`.

## Exact commands

```bash
# per cell, from the repository root
(cd spec/equiv/cells/limits/C-L-w32-sigop-count     && ./alive2/run.sh && ./saw/run.sh)
(cd spec/equiv/cells/limits/C-L-w32-p2sh-scriptsig  && ./alive2/run.sh && ./saw/run.sh)
(cd spec/equiv/cells/limits/C-L-w32-witness-sigops  && ./alive2/run.sh && ./saw/run.sh)
(cd spec/equiv/cells/limits/C-L-w32-sigop-cost      && ./alive2/run.sh && ./saw/run.sh)

# certificates
for c in C-L-w32-sigop-count C-L-w32-p2sh-scriptsig \
         C-L-w32-witness-sigops C-L-w32-sigop-cost; do
  sha256sum -c spec/equiv/cells/limits/$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/limits/$c/saw/certificate.sha256
done
```

The Alive2 runner invokes, for each function:

```bash
alive-tv --always-verify --smt-to=60000 build/c_<fn>.ll build/l_<fn>.ll
```

and refuses to accept a result if the extracted IR contains `alloca`,
`= external`, `switch.table`, or residual `llvm.loop` metadata, or if the
summary is not exactly `1 correct / 0 incorrect / 0 failed-to-prove /
0 Alive2 errors`.

## Raw outcomes

- `C-L-w32-sigop-count/alive2/result.txt`: two `STATUS=alive2-green
  function=...` lines and `STATUS=alive2-green`; each summary is
  `1 correct transformations`, `0 incorrect`, `0 failed-to-prove`, `0 Alive2
  errors`.
- `C-L-w32-sigop-count/saw/result.txt`: four `Proof succeeded!` lines and
  `STATUS=saw-green`.
- `C-L-w32-p2sh-scriptsig`: Alive2 green for `cell_p2sh_sigops`; SAW two
  proofs, green.
- `C-L-w32-witness-sigops`: Alive2 green for `cell_witness_sigops`; SAW two
  proofs, green.
- `C-L-w32-sigop-cost`: Alive2 green for `cell_sigop_cost`; SAW two proofs,
  green.

## The Alive2 loop trap

The first draft of the P2SH cell used `for` loops.  Alive2 reported "1 correct
transformations" even for a mutation (`return 999u;`) that the same IR
executes as 999 for scriptSig `02 52 ae`.  A residual loop is not a
trustworthy Alive2 input.  All four cells now unroll every walk with an
explicit live flag; `grep -c llvm.loop` is 0 in every extracted module, and
the shared runner fails the cell if `llvm.loop` appears.  Mutation checks with
the unrolled IR are caught:

- `C-L-w32-sigop-count`: inaccurate multisig `20 → 19` is a real
  counterexample.
- `C-L-w32-p2sh-scriptsig`: accurate multisig `return prev_num; → return
  999u;` is a counterexample.
- `C-L-w32-witness-sigops`: v0-20 `return 1; → return 2;` is a counterexample.
- `C-L-w32-sigop-cost`: `LEGACY_SIGOP_SCALE 4 → 5` is a counterexample.

## SCR-036 — exact blocker

`CountWitnessSigOps(scriptSig, scriptPubKey, witness, flags)`
(interpreter.cpp:2160-2182) has a P2SH-wrapped arm:

```
if (scriptPubKey.IsPayToScriptHash() && scriptSig.IsPushOnly()) {
    ... parse scriptSig, keep the last pushed data d ...
    CScript subscript(d);
    if (subscript.IsWitnessProgram(version, program))
        return WitnessSigOps(version, program, witness);
}
```

A non-zero return requires `version == 0` and `program.size() == 20` or `32`
(interpreter.cpp:2133-2147), so `d` must be 22 or 34 bytes.  `d` is the *last
pushed data*, so the scriptSig is at least `1 + 22 = 23` bytes (v0-20) or
`1 + 34 = 35` bytes (v0-32) even with a direct push.  The limits ABI packs the
whole script into one 64-bit word and every cell domain is 4 bytes; an 8-byte
word cannot hold 22 bytes, let alone 34.  This is an input-representation
limit, not a solver timeout: no Alive2/SAW run of the current ABI can reach the
positive arm.

The negative arms (non-push-only scriptSig, malformed scriptSig, last element
not a witness program, v0-16/v1 program, empty witness) are representable and
could be a partial cell, but they do not close the row; no cell is claimed for
SCR-036.

**Smallest next experiment:** add a `cell_count_witness_p2sh` with either

1. a 5 × uint64 packed scriptSig (40 bytes) plus length, keeping the same
   unrolled parser and `-fno-jump-tables`; or
2. a decoded-push descriptor `(first two redeem bytes, redeem length, witness
   item, stack size)` — justified because `IsWitnessProgram` reads only
   `d[0]`, `d[1]`, and `d.size`, and `WitnessSigOps` reads only the version and
   program size.

Option 1 is the conservative choice; it needs a higher Alive2 SMT budget
(the 8-byte-word proto-cell already needed `--smt-to=60000` for four bytes)
and a 5-word byte-dispatch harness.  Option 2 is cheaper and directly matches
the fields the two Core functions read, but its trust note must record the
field-read argument.

## Harness notes

- Cell ABI: `extern "C" uint32_t cell_*(uint64_t w, uint32_t len)` (plus the
  count arguments for the cost cell); `w` packs bytes little-endian, byte i =
  `(w >> 8*i) & 0xff`.
- The four-byte domain is a deliberate bound.  Eight bytes made Alive2 exceed
  its SMT budget.  Out-of-domain lengths return `0xffffffff` in both legs and
  in the Cryptol spec; the sentinel is above every possible count (≤ 80) and
  both tools prove the guards identical, so it cannot hide an in-domain
  disagreement.  It is not a claim about longer scripts.
- Parser/walk code is written independently in each leg (`c_leg.cpp` from
  Core's `GetScriptOp`/loops, `l_leg.cpp` from the Lean `getOp`/counter
  definitions); only the byte unpacking is shared harness.
- No `llvm_unsafe_assume_spec`, no hand-written status markers, no use of
  `results/**`, the shared ledger, `make equiv`, or any pin/contract/Lean
  edit.  Build artifacts stay in the gitignored `build/`; certificates hash
  tracked files only.

## Files

- `spec/equiv/cells/_tools/limits/{limits_common.h,build_limits.sh,run_alive2.sh,run_saw.sh}`
- `spec/equiv/cells/limits/C-L-w32-sigop-count/`
- `spec/equiv/cells/limits/C-L-w32-p2sh-scriptsig/`
- `spec/equiv/cells/limits/C-L-w32-witness-sigops/`
- `spec/equiv/cells/limits/C-L-w32-sigop-cost/`
- `spec/equiv/findings/wave32/07-limits-032-037/report.md`
