# Wave 64 / 40-scr-175 — LOW_S flag-source separation

| field | value |
| --- | --- |
| branch | `wave64/40-scr-175` |
| base / `repo_head` | `5946c024546e39f55775bfd9a077b042e3feeef4` |
| Core pin | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` |
| contract | `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` |
| tools | alive-tv 20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang 20.1.2 |
| cell | `spec/equiv/cells/policy-flags/C-L-lows-flag-source` |
| row | SCR-175 (`SCRIPT_VERIFY_LOW_S` is mempool policy, never in `GetBlockScriptFlags`) |
| patches | none |
| shared files touched | none |

## What was missing

SCR-175 already had two cells for the **gate**: `C-L-lows-policy` and
`C-L-w32-lows` prove what `CheckSignatureEncoding` does when the LOW_S bit is
set, and both **cite** `GetBlockScriptFlags` / `policy.h` as the source fact
that LOW_S is policy-only.  No cell machine-checked that source fact.  That is
the gap this cell closes.

## What the cell proves

For **every** block hash (four symbolic 64-bit limbs) and **every** uint32
height, over the exact `GetBlockScriptFlags` control flow and the exact
`policy.h` words:

```
(STANDARD_SCRIPT_VERIFY_FLAGS  >> 3) & 1 = 1   // policy.h:125
(MANDATORY_SCRIPT_VERIFY_FLAGS >> 3) & 1 = 0   // policy.h:104-110
(GetBlockScriptFlags(...)      >> 3) & 1 = 0   // validation.cpp:2249-2288
packed separation word                    = 1   // bit0=1, bit1=0, bit2=0
```

Bit 3 is `SCRIPT_VERIFY_LOW_S` (`verify_flags.h:25` + the `interpreter.h:64`
ordinal).  Every selector branch is in the symbolic domain: the normal
`P2SH|WITNESS|TAPROOT` base, both `script_flag_exceptions` replacements, the
fail-closed lookup for every other hash, and both sides of the four buried
height comparisons.

## Both-tool results (real runs)

| lane | checks | result |
| --- | --- | --- |
| Alive2 v20.0 | 4 roots x {C<->L bidirectional, C->postcondition, L->postcondition} = 12 | all `1 correct / 0 incorrect / 0 failed-to-prove / 0 Alive2 errors`; no loops |
| SAW 1.6 | 4 roots x 2 legs x 2 specs = 16 `Proof succeeded!` + model-theorem marker | green; no failed proof |

The SAW model (`saw/cell.cry`) is written independently from the pinned
headers and recomputes both policy words and the whole block word.  It also
proves `separation h0 h1 h2 h3 height == 1` over the full domain (SAW 1.6 is
silent on a successful `prove_print`, so the script prints
`CELL_policy_flags_lows_source_MODEL_PROOF_GREEN` only after it returns).

Certificates are tracked-input certificates: both `certificate.sha256` files
cover the cell record, both C++ legs, the property-target module, the harness
header and runners, the tracked `ir/*.ll` modules actually given to Alive2,
the Cryptol model/script, and the raw `result.txt`.  `sha256sum -c` passes for
both from a fresh checkout.

## Engineering note: `-O0` is load-bearing

At `-O1`, clang can see that no selector branch sets bit 3 and emits
`ret i64 0` for the block observable (and `ret i64 1` for the packed word).
That is a true compiled program but a vacuous C<->L comparison.  The cell
therefore compiles at `-O0` (the primary lane in `PINS.lock`) with
`always_inline` helpers, and the IR keeps the comparisons and branches.  The
IR was inspected before the runs and the tracked `ir/` modules are the ones
the certificates hash.

## Row disposition and remaining gap

- **Closed here:** the flag-source separation half of SCR-175, full over the
  selector's whole input domain.
- **Still open (not this task):** the numeric/gate half of SCR-175 —
  variable-length DER shapes (`lenR > 1`, `lenS != 32`), the size-bound
  rejects, and the libsecp256k1 DER-lax parse / scalar-overflow window.  That
  remains partial in `C-L-lows-policy` and `C-L-w32-lows` and needs a
  symbolic-length, byte-addressed signature model.
- **No contract/tape cell is possible for this half.**  The harness contract's
  `flags` argument is an *input* to `VerifyScript`; a tape cell observes the
  verdict for a supplied word, never which source supplied the bit.  Passing
  LOW_S in is the gate cell; observing the loader requires `ConnectBlock` /
  mempool caller wiring, outside `core_ref` validation.cpp:2249-2288.  So
  this bounded leaf is the correct cell shape, not a blocker report.

## Gate status

`python3 spec/equiv/tools/gate_ir_pin.py --allow-todo`:
- pins: OK; 183/183 SCR rows adjudicated; this cell's two certificates replay
  cleanly.
- The command still exits non-zero on **pre-existing** failures in
  `stack-ops/C-L-pick` (224 certificate issues pointing at its gitignored
  `build-saw/` artifacts).  Those failures are present on the base commit and
  are unrelated to this cell; they are not caused or repaired here.

## Files

```
spec/equiv/cells/policy-flags/C-L-lows-flag-source/
  spec.md, notes.md, buildspec
  c_cell.cpp, l_cell.cpp, spec_cell.cpp
  _tools/lows_source_common.h, _tools/build_leaf.sh
  alive2/run.sh, alive2/result.txt, alive2/certificate.sha256
  saw/run.sh, saw/cell.cry, saw/cell.saw,
  saw/result.txt, saw/certificate.sha256
  ir/build.txt, ir/{c,l,spec}_leaf.ll, ir/{c,l,spec}_<root>.ll
```

## Reproduce

```sh
bash spec/equiv/cells/policy-flags/C-L-lows-flag-source/alive2/run.sh
bash spec/equiv/cells/policy-flags/C-L-lows-flag-source/saw/run.sh
sha256sum -c spec/equiv/cells/policy-flags/C-L-lows-flag-source/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/policy-flags/C-L-lows-flag-source/saw/certificate.sha256
```
