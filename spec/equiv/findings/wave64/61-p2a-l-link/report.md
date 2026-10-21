# Wave 64 — task 61: SCR-055 L-link determination

**Worktree:** `/tmp/opencode/wave64/61-p2a-l-link`
**Branch:** `wave64/61-p2a-l-link` (base `5946c02`)
**Cell:** `spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor` (SCR-055)
**Pin:** `cce32b168` · **Contract:** `f1841e36…`

## Question

The cell's L leg is a reviewed transcription of `Defs.lean:523-526`, and the
cell does not prove the C-L binding of the predicate into
`VerifyWitnessProgram`'s P2A branch.  Can a real generator-linked L leg be
built, or must the exact missing Lean/twin hook be filed?

## Determination

**It can be built, and it is small — but it cannot land from this cell's write
scope.** The complete hook is 48 added lines in `twin/runtime.inc`
(two helpers + a decoder) plus two branch sites.  I built it in a scratch tree
and proved it:

| check | result |
|---|---|
| generator drift gate (`gen.py --check`) | clean (hook lives in the template, not the emitter) |
| Alive2, predicate `cell_p2a`, bidirectional | 1 correct, 0 incorrect, 0 failed-to-prove, 0 errors |
| Alive2, branch `cell_p2a_branch`, bidirectional | 1 correct, 0 incorrect, 0 failed-to-prove, 0 errors |
| SAW 1.6, both legs vs Cryptol | 4 × `Proof succeeded!`, 0 failed |
| twin smoke suite (pinned clang) | `cases=147 failures=0` |
| contract-entry tape table (`equiv_entry`) | 10/10: 8 Core verdicts + 2 declared E4 boundaries |
| Lean model (`lake env lean`, `core` built) | 12/12 evaluations match the twin table |

It is filed rather than landed for two independent reasons:

1. **Shared trust-base edit.** `twin/runtime.inc` is content-addressed by 42
   `certificate.sha256` files (21 cells, both legs) and
   `tools/gate_ir_pin.py:254` replays every certificate.  Landing the hook is
   a 21-cell re-certification event, not a cell edit (`GOAL.md` → "If a file
   must change outside your scope, write a handoff instead of editing it").
2. **Concurrent writer.** Wave-64 task 62 (`62-sha1-twin`) owns a twin change
   in the same files; two independent edits to `runtime.inc` would collide.

Handoff with the exact patch and acceptance test:
`spec/equiv/findings/handoffs/CELLS-to-TWIN-002-p2a-anchor-hook.md`.

## What the hook contains

In `twin/runtime.inc` (base line numbers):

- after `is_witness_program` (`:312-320`):
  - `is_pay_to_anchor(version, program, plen)` — `Defs.lean:523-526`,
  - `pay_to_anchor_branch(version, program, plen, is_p2sh)` — `Defs.lean:1319`,
  - `decode_witness_program(b, n, out)` — `Defs.lean:510-521`; the twin's
    recognizer returns a Boolean only, so the branch needs the decoded pair.
- bare-witness arm (`:806-810`): the P2A branch, returning `TWIN_OK` before
  the `TWIN_INVALID_UNSUPPORTED` E4 sentinel.
- P2SH-witness arm (`:829-835`): `is_p2sh = true` excludes the P2A branch by
  its own guard, so a v1 2-byte program takes the unencumbered tail
  (`discourage ? DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM : OK`).

The cell's L leaf then becomes two thin wrappers over generated twin
functions, with only the two-byte buffer as harness (the pattern already used by
`push-encoding/C-L-w32-witness-program` and `C-L-w32-pushonly-opcode`):

```cpp
#include "twin.cpp"

extern "C" uint64_t cell_p2a(uint8_t version, uint8_t p0, uint8_t p1,
                             uint32_t plen) {
  const uint8_t program[2] = {p0, p1};
  return twin::is_pay_to_anchor(version, program, plen) ? 1u : 0u;
}

extern "C" uint64_t cell_p2a_branch(uint8_t version, uint8_t p0, uint8_t p1,
                                    uint32_t plen, uint8_t is_p2sh) {
  const uint8_t program[2] = {p0, p1};
  return twin::pay_to_anchor_branch(version, program, plen, is_p2sh != 0)
             ? 1u : 0u;
}
```

The C side of the probe is the same four-conjunct excerpt plus the
`interpreter.cpp:2000` guard (`if (is_p2sh) return 0;`), so the Alive2
comparison covers the guard too.

## Three-way evidence (binding)

`equiv_entry` on canonical `TX_WITH_WITNESS` tapes; expected values read from
the pinned Core source (`script.cpp:207-222`, `interpreter.cpp:2000`,
`:2047-2056`, `:2089-2102`).  The Lean column is
`verifyWitnessProgram 200000 … {witness := true} pol default isP2SH` from
`p2a_link_probe.lean`.

| case | Core | twin+hook | Lean model |
|---|---|---|---|
| bare P2A, no witness | pass `/ 0` | pass `/ 0` | `.ok` |
| bare P2A, empty witness list | pass `/ 0` | pass `/ 0` | `.ok` |
| bare P2A, one-item witness | pass `/ 0` | pass `/ 0` | `.ok` |
| bare P2A + DISCOURAGE_UWP | pass `/ 0` (branch precedes the check) | pass `/ 0` | `.ok` |
| bare P2A + CLEANSTACK | pass `/ 0` (Core resizes to 1) | pass `/ 0` | `.ok` |
| bare P2A, scriptSig non-empty | fail `/ 41` WITNESS_MALLEATED | fail `/ 41` | n/a (VerifyScript arm) |
| P2SH-wrapped P2A | pass `/ 0` (`!is_p2sh` guard) | pass `/ 0` | `.ok` |
| P2SH-wrapped P2A + DISCOURAGE_UWP | fail `/ 34` | fail `/ 34` | `.fail discourage…` |
| bare v1 2-byte `4e74` | pass `/ 0` | **3 (E4)** | `.ok` |
| bare v0 20-byte, empty witness | fail `/ 40` | **3 (E4)** | `.fail witnessProgramMismatch` |

The last two rows are the unchanged witness-engine seam: they are outside
SCR-055 and the twin keeps returning result 3 (never a verdict).  Everything
that the row names — the predicate and the P2A branch, native and wrapped,
including the policy-ordering edge — matches on all three legs.

## Lean-side finding (ledger, not model)

The Lean model already proves the binding, so no model change is needed:

- `BitcoinProofs.AF.PDW57.isPayToAnchor_iff` — `@[rule "SCR-055"]`, exact iff.
- `BitcoinProofs.AF.PDW41.verifyWitnessProgram_p2a_ok` — `@[rule "TPR-004"]`,
  native P2A → `.ok` for *every* witness, flag set, policy set and checker.
- `BitcoinProofs.AF.PDW59.verifyWitnessProgram_v1_anchor_ok` (`SCR-150`),
  `verifyWitnessProgram_v1_p2sh_ok`, `…_v1_p2sh_discourage`,
  `…_v1_wrong_size_{ok,discourage}` (`SCR-151`).

But `spec/db/rules.yaml` SCR-055 says:

```yaml
check: "IsPayToAnchor"
lean_target: "Bitcoin.Interpreter.Defs.isWitnessProgram"
```

i.e. the row's Lean target is the *recognizer* (`Defs.lean:508`, tagged
SCR-053/054/055), not the anchor predicate or the branch theorem.  The
per-definition target is therefore the missing Lean hook; the ask is in the
handoff (LEDGER scope, regenerate `axiom-audit-rows.txt`).

`Defs.isPayToAnchor` itself is deliberately untagged: PDW57/PDW41/PDW59 carry
the rule tags ("Route B: tags on my theorems, zero core writes"), so tagging
the core definition is **not** requested.

## Exact execution record (scratch tree)

The probe ran outside the worktree at `/tmp/opencode/61-p2a-probe`, a copy of
`spec/equiv/{twin,contract,cells/_tools/w32-push,mk_leaf.py}` plus the cell.
Nothing in the worktree was patched for the probe.

| artifact | sha256 |
|---|---|
| base `twin/runtime.inc` | `465388db548f053bd06dbc93f1620600f7233cbcfb58f410ff505c6c5828725c` |
| patched `twin/runtime.inc` | `7c8824e48b1b5a93ae32daa9606bca333118e33d95bf7f25f63e03dd25b90aa1` |
| patch file (`runtime.inc`, a/b headers) | `5dd8bff94995b547f9777e7da58bd2499bc18844a8fffcf2ee42b905bceead0e` |
| rendered `twin.cpp` (patched) | `df78b78e22750aaa99704849a8e007be851c201e68fcd1802c5fd4c6287afbdc` |
| rendered `twin.ir.json` (patched) | `e5fbe72707a43bfc950ad67e4a86eff3c4c3c4314aa17323c2a23b9f3cfd6413` |
| base `twin.cpp` (cell build) | `39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f` |

Commands (from the scratch root):

```sh
twin/gen.py --out twin/build/twin.cpp --dump-ir twin/build/twin.ir.json
twin/gen.py --check twin/build/twin.cpp                     # OK
CXX=clang++-20 twin/smoke.sh --require-clang                # 147/147 PASS
cells/_tools/w32-push/build.sh cells/push-encoding/C-L-w32-p2a-anchor
alive-tv --bidirectional --smt-to=60000 build/c_cell_p2a.ll build/l_cell_p2a.ll
alive-tv --bidirectional --smt-to=60000 build/c_cell_p2a_branch.ll build/l_cell_p2a_branch.ll
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw build/cell.saw  # 4 proofs
python3 binding_probe.py                                    # 10/10
cd <repo>/spec && lake build core && lake env lean equiv/findings/wave64/61-p2a-l-link/p2a_link_probe.lean
```

Raw Alive2 tail (identical for both entry points):

```text
Transformation seems to be correct!

These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
```

Raw SAW tail:

```text
Proof succeeded! cell_p2a
Proof succeeded! cell_p2a
Proof succeeded! cell_p2a_branch
Proof succeeded! cell_p2a_branch
CELL_W32_P2A_GENLINK_SAW_GREEN
```

Raw contract-entry table:

```text
10/10 cases match (8 Core verdicts, 2 E4 boundaries)
```

Raw Lean output (12 lines):

```text
true / false / false / false / false
ok / ok / ok / ok
fail (discourageUpgradableWitnessProgram) / ok
fail (witnessProgramMismatch)
```

## Residuals

- The hook is not landed here; SCR-055 keeps its transcribed L leg until
  TWIN-002 lands and the 21 cells are re-certified.  The cell's `trust_note`
  and `notes.md` now point at the handoff so the caveat is not a dead end.
- `make gate-ir-pin` is red at the **base commit** in this worktree: 224
  certificate issues / 225 failures, all `missing <build artifact>` lines from
  cells whose certificates hash `build/` outputs that a fresh checkout does
  not contain.  The count is identical before and after this task, none of the
  issues reference this cell, and
  `sha256sum -c …/alive2|certificate.sha256` plus the ledger drift check
  (`update_ledger.py --check` → `changes: 0`) are clean.  Re-running this cell
  leaves `result.txt` byte-identical (`2f4ec58d…`, `5d09bd7c…`), so no shared
  ledger row moved.
- Not attempted: the twin's `corpus_probe.py` differential on the patched twin
  (the scratch tree has no copy of the Core parser ref); failure 3 is already
  covered by the smoke suite, which includes the witness bookkeeping cases.
- Still E4 (unchanged): witness-v0 execution and v1-32 taproot execution.
