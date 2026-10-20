---
# Cell tapscript/C-L-taproot-gate
cell: C-L-taproot-gate
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (one total symbolic dispatch predicate)
precondition: |
  - Cell seam: the head of the taproot arm of VerifyWitnessProgram
    (interpreter.cpp:1957-1969) only.
  - `version` is the witness version produced by CScript::IsWitnessProgram
    (0..16 in the engine; the function is total and treats every other shape
    as outside the arm).
  - `program_len` = program.size() in bytes; `is_p2sh` = the P2SH-wrapped
    call-site flag; `taproot_flag` = SCRIPT_VERIFY_TAPROOT.
  - `witness_n` = witness stack item count. No item bytes are needed by the
    gate predicate.
  - No SHA256, no Schnorr/EC, no EvalScript, no ExecuteWitnessScript, no
    transaction or block context is modelled.
postcondition: |
  - Packed observable result(2) | error_ordinal(6) << 2.
  - version=1, program_len=32, is_p2sh=0, taproot_flag=0 -> (1, 0)
    (Core :1959 set_success: silent success, no witness inspection).
  - version=1, program_len=32, is_p2sh=0, taproot_flag=1, witness_n=0
    -> (0, 39) WITNESS_PROGRAM_WITNESS_EMPTY.
  - version=1, program_len=32, is_p2sh=0, taproot_flag=1, witness_n>0
    -> (2, 0) continuation into the annex/key/script dispatch.
  - any other shape -> (3, 0) outside this arm.
  - Codes 2 and 3 are cell-harness markers, not engine results.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-142
scr_row_coverage: |
  partial. The in-function gate is proved total: flag off -> success with no
  witness inspection; flag on -> empty witness fails 39, non-empty continues
  into the annex/key/script dispatch. The row also names activation height
  709632 and exception block 692261. Those are caller-side flag assembly
  outside VerifyWitnessProgram and have no block-height channel in
  contract/tape.md, so that arm is not exercised here.
patches: none
source_citations:
  - "interpreter.cpp:1957 (v1-32 non-P2SH arm condition)"
  - "interpreter.cpp:1959 (if (!(flags & SCRIPT_VERIFY_TAPROOT)) return set_success(serror))"
  - "interpreter.cpp:1960 (empty witness -> SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY)"
  - "interpreter.h:240 (WITNESS_V1_TAPROOT_SIZE = 32)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1280 (version=1 / size=32 / !isP2SH)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1282 (!flags.taproot -> .ok)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1283-1284 (empty witness -> .witnessProgramWitnessEmpty)"
  - "spec/core/Bitcoin/Interpreter/Rules.lean:374-381 (verifyWitnessProgram_taproot_gate_silent_ok)"
  - "contract/error_enum.md:78 (ordinal 39)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin. L is a reviewed transliteration of the Verified Lean
  verifyWitnessProgram taproot arm; the twin has no VerifyWitnessProgram
  handler, so it is not generated from twin/ops_ir.py. No hash, signature,
  script-loop or block-context semantics is modelled. Both tools prove the
  same total symbolic predicate: Alive2 compares the C and L IR
  bidirectionally; SAW verifies each leg against one shared Cryptol statement
  derived from the Core branch table. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: in l_leg.cpp make the taproot_flag==0 branch return
  TAP_FAIL/0 instead of TAP_OK. Expected Alive2 counterexample at
  version=1, program_len=32, is_p2sh=0, taproot_flag=0 (C packs 1, L packs 0);
  expected SAW proof failure for the L module.
mutant_site: "cells/tapscript/C-L-taproot-gate/l_leg.cpp l_taproot_gate, :1282 branch"
---

# `tapscript/C-L-taproot-gate`

## What is proved

One total symbolic function per leg, `cell_taproot_gate(version, program_len,
is_p2sh, taproot_flag, witness_n)`. Alive2 quantifies over every 64-bit tuple;
SAW verifies the same statement against the Cryptol predicate in
`build/cell.cry`.

| shape | result |
|---|---|
| v1, 32-byte program, non-P2SH, TAPROOT flag off | success, no witness inspection |
| same, flag on, empty witness | error 39 `WITNESS_PROGRAM_WITNESS_EMPTY` |
| same, flag on, non-empty witness | continue to annex/key/script dispatch |
| any other shape | outside this arm |

The flag-off row is the "silent success" behavior: Core returns before
touching the witness stack. The flag-on empty row is the reason a v1-32 spend
is not anyone-can-spend once the flag is active.

## What is not proved

- The activation-height/block-exception arm of SCR-142 (709632 / 692261).
  That is caller-side flag assembly; the tape has no height channel.
- Annex detection (SCR-143), key path (SCR-144), control block and leaf
  version (SCR-145/148/149), upgradable versions (SCR-150/151): sibling cells
  under `cells/tapscript/`.
- Any whole-engine ingestion. This is a bounded dispatch leaf.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-gate/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-gate/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-gate/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-gate/saw/certificate.sha256
```
