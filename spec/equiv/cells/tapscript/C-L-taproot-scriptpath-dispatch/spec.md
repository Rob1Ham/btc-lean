---
# Cell tapscript/C-L-taproot-scriptpath-dispatch
cell: C-L-taproot-scriptpath-dispatch
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (three total symbolic dispatch predicates)
precondition: |
  - Cell seam: the script-path dispatch tail of VerifyWitnessProgram after
    the control/script pops: control-size gate (interpreter.cpp:1980-1982),
    leaf-version dispatch (:1988-1998), and the post-taproot upgradable tail
    (:2000-2008). The tapleaf commitment (SCR-146/147) is abstracted: the
    cell starts after a successful commitment check, which is a precondition.
  - cell_control_size: `size` is control.size() in bytes, arbitrary 64-bit.
  - cell_leaf_version: `control0` is control[0] (masked to a byte);
    `discourage_taproot` is the SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION
    policy bit.
  - cell_tail: `version` is the witness version (0..16 from
    CScript::IsWitnessProgram; other values are a harness domain guard),
    `program_len` and `prog0`/`prog1` are the program bytes, `is_p2sh` is the
    call-site flag, `discourage_witness` is
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM.
  - v0 and the native v1-32 arm are deliberately delegated markers; their
    outcomes belong to other cells.
  - No SHA256/tagged hash, no EC tweak, no Schnorr, no EvalScript.
postcondition: |
  - cell_control_size(size):
      size < 33 || size > 4129 || (size-33) % 32 != 0 -> (0, 48)
        SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE
      otherwise                                        -> (1, 0)
  - cell_leaf_version(control0, discourage_taproot):
      (control0 & 0xfe) == 0xc0 -> (2, 0) tapscript arm selected
      else discourage set       -> (0, 35) DISCOURAGE_UPGRADABLE_TAPROOT_VERSION
      else                      -> (1, 0) upgradable success
  - cell_tail(version, program_len, prog0, prog1, is_p2sh, discourage_witness):
      version outside 0..16 or version 0 -> (3, 0) delegated
      version 1, len 32, non-P2SH         -> (3, 0) delegated (taproot arm)
      non-P2SH v1 len 2 with bytes 4e73   -> (1, 0) P2A success, no execution
      discourage witness set              -> (0, 34) DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
      otherwise                           -> (1, 0) upgradable success
  - Codes 2 and 3 are cell-harness markers, not engine results.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-145, SCR-148, SCR-149, SCR-150, SCR-151
scr_row_coverage: |
  full for all five rows, at the dispatch tier:
  - SCR-145 (control size 33+32k, k<=128): total u64 arithmetic predicate,
    exactly Core :1980-1982 with constants 33/32/4129.
  - SCR-148 (control[0]&0xfe == 0xc0 => TAPSCRIPT eval): total 8-bit mask
    predicate; entering the tapscript arm is proved for exactly the two byte
    values 0xc0/0xc1 (parity bit ignored) and for no other byte. Script
    execution itself is SCR-153/155 and is not claimed.
  - SCR-149 (unknown leaf versions succeed; policy flag): total mask+flag
    dispatch. Non-0xc0 with the policy bit off succeeds; with it on fails
    with ordinal 35. The row text names
    DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM; at the pin the leaf-version branch
    uses DISCOURAGE_UPGRADABLE_TAPROOT_VERSION (interpreter.cpp:1995), which
    is what this cell proves.
  - SCR-150 (v1 2-byte 4e73 => success, no execution): exact
    IsPayToAnchor(version, program) predicate, non-P2SH, proved to precede the
    policy flag (it succeeds even with DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
    set, while every other upgradable shape fails 34).
  - SCR-151 (v2-v16 / wrong-size v1 / P2SH-wrapped v1 => success): total
    version/size/P2SH dispatch over the tail; success with the policy bit off,
    ordinal 34 with it on. The P2A v1-2 shape is routed to SCR-150's arm.
  - Not covered by this cell: the tapleaf tagged hash (SCR-146) and the EC
    commitment/parity check (SCR-147). They are preconditions here and are
    filed as blockers in the task report.
patches: none
source_citations:
  - "interpreter.cpp:1980-1982 (control size gate)"
  - "interpreter.cpp:1988 (control[0] & TAPROOT_LEAF_MASK == TAPROOT_LEAF_TAPSCRIPT)"
  - "interpreter.cpp:1995-1997 (DISCOURAGE_UPGRADABLE_TAPROOT_VERSION)"
  - "interpreter.cpp:1998 (return set_success)"
  - "interpreter.cpp:2000-2001 (IsPayToAnchor -> return true)"
  - "interpreter.cpp:2002-2008 (upgradable witness program tail)"
  - "script.cpp:216-222 (CScript::IsPayToAnchor)"
  - "interpreter.h:242-247 (TAPROOT_LEAF_MASK/TAPSCRIPT, control size constants)"
  - "spec/core/Bitcoin/Crypto/Taproot/Program.lean:490-499 (controlBlockSizeOk)"
  - "spec/core/Bitcoin/Script/Tapscript/LeafVersion.lean:29-70 (isTapscriptLeaf, verifyTaprootLeafDispatch)"
  - "spec/core/Bitcoin/Crypto/Taproot/Program.lean:554-555 (leafVersionOf)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:523-525 (isPayToAnchor)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1319-1321 (upgradable tail)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1796-1811 (verifyWitnessProgram_other_pass)"
  - "contract/error_enum.md:75,80 (ordinals 34, 35, 48)"
trust_note: >
  C legs are line-cited source-excerpt slices of Bitcoin Core interpreter.cpp
  and script.cpp at the pin. L legs are reviewed transliterations of
  controlBlockSizeOk, isTapscriptLeaf/verifyTaprootLeafDispatch, isPayToAnchor
  and the verifyWitnessProgram tail; the twin has no VerifyWitnessProgram
  handler, so they are not generated from twin/ops_ir.py. The tapleaf hash and
  EC commitment are preconditions (start after success), so this cell does
  not prove SCR-146/147 and makes no hash or EC claim. Both tools prove the
  same three total predicates: Alive2 compares C and L bidirectionally; SAW
  verifies each leg against one shared Cryptol statement. No Core patch.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: in l_leg.cpp change the control-size upper bound
  from 4129 to 4128, or the leaf mask from 0xfe to 0xff. Expected Alive2
  counterexample at size=4129 (first mutant) or control0=0xc1 (second mutant),
  and a SAW failure for the corresponding L function.
mutant_site: "cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp l_control_size / l_leaf_version"
---

# `tapscript/C-L-taproot-scriptpath-dispatch`

## What is proved

Three total symbolic functions per leg:

| function | rows | claim |
|---|---|---|
| `cell_control_size` | SCR-145 | exactly `33 <= size <= 4129 && (size-33)%32 == 0`; else ordinal 48 |
| `cell_leaf_version` | SCR-148/149 | `(c&0xfe)==0xc0` -> tapscript; other leaf versions -> 35 with policy, else success |
| `cell_tail` | SCR-150/151 | P2A v1-2 `4e73` success before the policy flag; every other non-taproot version/size/P2SH shape success, or 34 with the policy flag |

The predicates are proved over all 64-bit inputs; this is symbolic
enumeration of the rule, not a closed witness. Alive2 is bidirectional and
SAW checks both legs against `build/cell.cry`.

## Coverage notes

- SCR-148 proves the *dispatch* into the tapscript lane, not execution. The
  gap note in `findings/e4/seams.md` explicitly separates execution
  (SCR-153/155) from the mask predicate.
- SCR-149's row text uses `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`; the
  leaf-version branch at the pin uses
  `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION`. The cell proves the pinned
  behavior and records the naming discrepancy.
- SCR-150 "no execution" is structural: the P2A arm returns `true` directly
  and the cell has no `ExecuteWitnessScript` call on that path. The proved
  distinguishing behavior is that P2A succeeds even when the upgradable
  witness-program policy bit is set.
- v0 and the native v1-32 arm are delegated markers; they are other cells'
  subject.

## What is not proved

- SCR-146 (TapLeaf tagged hash) and SCR-147 (EC tweak/parity): the cell starts
  after a successful commitment check. These are filed blockers.
- Tapscript execution, OP_SUCCESS pre-scan, validation weight.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/saw/certificate.sha256
```
