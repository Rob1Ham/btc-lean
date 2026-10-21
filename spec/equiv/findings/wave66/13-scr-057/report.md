# wave66/13 — SCR-057 full closure (`CastToBool`, arbitrary element length)

**Base:** `8142cff0ed6ea6edd448b609817d2a706ab5e057` (PR #29)
**Branch:** `wave66/13-scr-057`
**Row:** `SCR-057` — “any nonzero byte = true; lone 0x80 = false; ∅ = false”,
`interpreter.cpp:46-59@cce32b168`
**New cell:** `spec/equiv/cells/control-flow/C-L-casttobool-full`
**Verdict:** `both-green` over the complete consensus element domain
`0 <= n <= 520` (all lengths, all byte values). The wave65 F3 domain gap
(“lengths 3..520 are a stated gap”) is closed; the older bounded cell is not
used for this claim.

## 1. Why the earlier row was demoted

`control-flow/C-L-casttobool` exported three functions with `vch.size()`
fixed at compile time (0, 1, 2), so clang unrolled the loop away and the
tools only saw lengths 0..2. It explicitly recorded lengths 3..520 as a
domain gap, which the wave65 snapshot audit (`findings/wave65/32-audit`,
F3) justly flagged as contradicting the row's `full` claim.

The new cell removes the compile-time length. It keeps the Core loop verbatim
and passes it a symbolic 32-bit length under Core's own element bound:

```c
uint32_t cell_cast_arb(const uint8_t* vch, uint32_t n) {
  __builtin_assume(n <= 520u);          // MAX_SCRIPT_ELEMENT_SIZE
  return core_cast_to_bool(vch, n) ? 1u : 0u;
}
```

`build/build.txt` records `loop_present_c=1` and `loop_present_l=1`: the
emitted IR still contains `!llvm.loop`, so neither tool is checking a
per-length unrolled instance.

The L leg is the twin's real `cast_to_bool`, extracted **verbatim** from
`spec/equiv/twin/runtime.inc` by `src/extract_twin.py`. The extractor pins the
SHA-256 of the exact function text; a twin change fails the build instead of
silently proving a different helper. No twin or shared proof is edited.

## 2. The machine-checked statement

For every `n` in `[0,520]` and every byte vector `b` of length `n`:

```
C(b) = L(b) = 1  iff  n > 0 and
    ( (exists i < n-1, b[i] != 0)  or  b[n-1] not in {0x00, 0x80} )
C(b) = L(b) = 0  otherwise
```

This is the scan/no-scan semantics:

* `n = 0` → false (∅ = false).
* A nonzero byte strictly before the last position stops the scan and returns
  true; the negative-zero test is guarded by `i == n-1`, so it cannot apply.
  In particular `0x80` before the last position is an ordinary nonzero byte
  and is **true**.
* If every pre-last byte is zero, only `b[n-1]` decides: `0x00` → false,
  `0x80` → false (the unique negative-zero case), any other nonzero byte →
  true.

The 0x80-only negative-zero rule is therefore proved for every position and
every length, not merely for a representative length.

## 3. Evidence

### Alive2 (C loop vs L loop, symbolic length)

`alive2/run.sh` builds and runs exactly:

```sh
alive-tv --bidirectional --smt-to=60000 \
  build/c_cell_cast_arb.ll build/l_cell_cast_arb.ll
```

Both functions take a symbolic `i32 n` constrained by `llvm.assume(n <= 520)`
and a pointer to a `[520 x i8]` region. `--bidirectional` checks both
refinement directions of the single C/L pair. No `--src-unroll`/`--tgt-unroll`
factor is passed; Alive2 reasons about the loop directly.

`alive2/result.txt`:

```
Transformation seems to be correct!

These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

### SAW (both legs vs an independent Cryptol predicate)

`saw/run.sh` runs exactly:

```sh
(cd build && saw cell.saw)
```

`src/cell.cry` is an independent transcription of the three named outcomes
and the scan/no-scan rule. The SAW setup allocates a fully symbolic
`[520][8]` array, takes a symbolic `i32 n`, and assumes only `n <= 520`; it
does not fix the length or sample lengths. Both `llvm_verify` calls (C and L)
are against that same predicate.

`saw/result.txt`:

```
Verifying cell_cast_arb...
Simulating cell_cast_arb...
Symbolic simulation completed with side conditions.
Checking proof obligations cell_cast_arb...
Proof succeeded! cell_cast_arb
Verifying cell_cast_arb...
Simulating cell_cast_arb...
Symbolic simulation completed with side conditions.
Checking proof obligations cell_cast_arb...
Proof succeeded! cell_cast_arb
CELL_control_CASTTOBOOL_FULL_SAW_GREEN
STATUS=saw-green
```

Two proofs succeeded, zero `Proof failed`. Elapsed 208.6 s, max RSS 241.8 MB
(`/usr/bin/time`). An earlier attempt on a heavily loaded host was killed by
the OS after 44 s; the successful rerun is the recorded result.

### Why this is complete, not a sample

Core's script-element bound is `MAX_SCRIPT_ELEMENT_SIZE = 520`. The length is
symbolic in both tools under that bound, so a single check covers all 521
lengths simultaneously; within each length, every byte position is symbolic
(`2^(8n)` vectors). This is a complete finite abstraction over the finite
consensus element domain, not an enumeration of a few lengths and not a
“lengths 3..520 are a gap” statement.

The row's own semantic reading is independently corroborated by the existing
machine-checked Lean theorem `Bitcoin.Numeric.castToBoolList_iff`
(`spec/core/Bitcoin/Numeric/ScriptNum.lean:656`), which proves the same
characterization for **all** byte lists: true iff the sign-magnitude value is
nonzero. That theorem is cited, not edited.

## 4. Tools and certificate hashes

| item | value |
|---|---|
| clang | Ubuntu clang 20.1.2 (`/usr/bin/clang++-20`) |
| LLVM | Ubuntu LLVM 20.1.2 (`llvm-as`, `llvm-extract`, `llvm-dis`) |
| Alive2 | `/usr/local/bin/alive-tv`, v20.0, LLVM 20 build |
| SAW | 1.6 (`68eed5f release-1.6`), solver `abc` |
| contract pin | `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` |
| core pin | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` |

Recorded artifact hashes:

```
alive2/result.txt               9b51c788ed835910fc4fe5edf2e36f503d017f790fe6b5ce67dca0f35e1e6649
alive2/certificate.sha256       6d75a1affe55abea84f825cfcdfd8a4eb84a551a82ced779a71fb0794844731d
saw/result.txt                  9cba827f7dda36f868e5407f56fba463ab07fcb0db534f95b8cc6c7a90e6f977
saw/certificate.sha256          d2e9d3cf1bce56fed5e8e2664c49375e3d5bee167f73e7d958155b8ccfe700c5

spec.md                         4c6d8b97aad65634dc533230991fc99bf27431d9eb103732aa2063a92bf43e4e
notes.md                        6fb49aa37ea908d34df44ddf42d9e6a553295e0aefc61f1ae3d1c102042d1c5f
src/c_leaf.cpp                  48217f026ed6b60d6ada84774a536ea1c6838e85753d864c1f45672531962259
src/l_leaf.cpp                  6c7de7718d3e0b7c5bfcf374acdf5053ecff6d5144120076d718c45d94a7304f
src/extract_twin.py             5f600f4280f573778979c2d675cebec01590637dc1d6215a45b52fec33862410
src/cell.cry                    c01dc14eaa427efeca4454563a2250742e62de9934c2ed59e65ca05c66181138
src/cell.saw                    c3235e046c3851b57b2b79b3a6f73fac5f35e3d67a7959b340caadf656651b86
twin/runtime.inc                465388db548f053bd06dbc93f1620600f7233cbcfb58f410ff505c6c5828725c
build/twin_cast_to_bool.h       cc1343838e4e3c8d32efceae57c9f370a5ecbae6e3b0882f8aa17745c584fa03
build/c_cell_cast_arb.ll        928b869a6f13c1ef04ce110a6cf521e8147a888e410d029977014fc7186ca8fb
build/l_cell_cast_arb.ll        77e8488e689eea93e461c5f95b34c82c01daca248a866cc04a367bfbc52a5d91
```

The IR hashes are checkout-root independent: the build script compiles from
the cell directory with relative paths, and a rebuild reproduces the same
hashes.

## 5. Non-vacuity (mutation probe)

To show the Alive2 query and SAW specs actually constrain the 0x80 case, the L
IR was mutated to disable the negative-zero branch (`%or.cond.not.i = or i1
true, %cmp2.i`, so a nonzero last byte is always true). The C leg was left
unchanged. Exact commands: `spec/equiv/cells/control-flow/C-L-casttobool-full/mutant/run.sh`.

Alive2 found the expected counterexample:

```
i32 noundef %n = #x00000001 (1)
i8 %#0 = #x80 (128, -128)
Source value: #x00000000 (0)     // C: negative zero is false
Target value: #x00000001 (1)     // mutated L: true
 1 incorrect transformations
```

Full log: `alive2-negzero-off.txt`.

SAW likewise passed the C proof and failed the mutated L proof:

```
Proof succeeded! cell_cast_arb
Subgoal failed: cell_cast_arb ...
Proof failed.
```

Full log: `saw-negzero-off.txt`.

## 6. Scope and residual

* **Closed:** SCR-057 for every element length `0..520` and every byte value,
  with `0x80` at the last position as the only false nonzero byte, unconditional
  `∅ = false`, and `0x80` before the last position true.
* **Not claimed:** whole-engine `VerifyScript`/`EvalScript`, flags, sigversion,
  stack effects, or elements longer than `MAX_SCRIPT_ELEMENT_SIZE = 520`
  (outside Core's script-element invariant). This is a predicate cell, like
  the other `CastToBool` evidence.
* **No shared edits:** this branch adds only the new cell and this finding.
  `spec/db/equiv-cells.yaml`, `spec/equiv/results/*`, `spec/equiv/docs/*`,
  `spec/equiv/twin/*`, the contract/pins, and the existing
  `control-flow/C-L-casttobool` are untouched. The older cell remains an
  honestly labelled length-0..2 cell and is not used for the full claim.
* **Intended ledger effect (for the integrator):** because
  `scr_row_coverage` for this cell starts with `full` and carries no `partial`
  bullet, `spec/equiv/results/scripts/update_ledger.py` should derive
  SCR-057 as `both-green` with this cell and drop the auto gap note. That
  regeneration is deliberately left to integration; this branch does not edit
  the ledger.
