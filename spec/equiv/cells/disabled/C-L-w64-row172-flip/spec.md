---
# Cell disabled/C-L-w64-row172-flip
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: disabled/C-L-w64-row172-flip
family: disabled-opcodes
tool_status: both-green (symbolic over all 2^8 wire bytes x all 2^64 flag words; two functions)
precondition: |
  - The script is exactly ONE byte `w` with 0x4f <= w <= 0xff. Every such
    byte is a single opcode with no push payload, so `GetOp` consumes one
    byte and cannot fail. 0x4f is OP_1NEGATE; direct pushes (<= 0x4b) and
    PUSHDATA (0x4c-0x4e) are outside the domain because a one-byte script
    ending inside a push payload is BAD_OPCODE (F-DIV-001 territory, not
    this row). Out-of-domain inputs return 254 on both sides.
  - BASE side: SigVersion::BASE at top level, fExec = true, nOpCount = 0.
    WITNESS_V0 has the same disabled arm (interpreter.cpp:459-482); the
    disabled arm is reached after GetOp, push-size and op-count, none of
    which can fire for this one-byte non-push input. Only the disabled arm
    is classified: reaching the switch is the marker 64, not a verdict.
  - TAPSCRIPT side: ExecuteWitnessScript's OP_SUCCESSx pre-scan over the
    same one-byte script (interpreter.cpp:1846-1862), before EvalScript and
    before the initial-stack/item-size checks. If the scan finds no success
    byte, the marker 66 means the scan completed and EvalScript would run;
    this cell does not model that continuation.
  - `flags` is the 64-bit verification-flag word (contract ABI / Core script_verify_flags). The policy flag
    SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS is script_verify_flag_name ordinal
    19 (interpreter.h:143-144), so it maps to bit 1 << 19 = 0x80000
    (verify_flags.h: script_verify_flags(script_verify_flag_name) =
    1 << ordinal). No other flag is read.
  - No stack content, tx, hash, signature, annex, control block, or
    execution budget is modelled.
postcondition: |
  - `cell_pair(w, flags)` = (BASE_outcome << 32) | TAPSCRIPT_outcome:
      BASE_outcome(w):      254 if w < 0x4f;
                            17  (SCRIPT_ERR_DISABLED_OPCODE) iff w is one of
                                the fifteen CVE-2010-5137 wires
                                {0x7e,0x7f,0x80,0x81,0x83,0x84,0x85,0x86,
                                 0x8d,0x8e,0x95,0x96,0x97,0x98,0x99};
                            64  otherwise (base reaches the EvalScript switch).
      TAPSCRIPT_outcome(w): 254 if w < 0x4f;
                            0   (OK) iff IsOpSuccess(w) and the policy bit
                                is clear;
                            36  (SCRIPT_ERR_DISCOURAGE_OP_SUCCESS) iff
                                IsOpSuccess(w) and flags bit 19 is set;
                            66  otherwise (scan completes, EvalScript runs).
    IsOpSuccess is exactly Core's script.cpp:365-371 set
    {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254}.
  - `cell_flip(w, flags)` = 1 iff BASE_outcome = 17 AND TAPSCRIPT_outcome is
    0 or 36. By the two tables this is exactly the fifteen disabled wires,
    for both positions of the policy bit: the same byte that is a consensus
    DISABLED_OPCODE error in BASE/WITNESS_V0 is an unconditional
    OP_SUCCESSx result in tapscript (OK, or the policy-level
    DISCOURAGE_OP_SUCCESS error when the node sets bit 19). Every other
    wire, including the non-disabled OP_SUCCESSx bytes 0x50/0x62 and
    0xbb-0xfe, returns flip = 0: this row is the fifteen-wire
    disabled-to-success flip, not the whole success set.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-172
scr_row_coverage: >-
  partial, with the flip itself machine-checked on a one-byte script.
  Proved: for every 8-bit wire and every 64-bit flag word the BASE disabled
  classification and the tapscript one-byte OP_SUCCESSx pre-scan are exactly
  the table above, and the fifteen legacy-disabled wires are precisely the
  bytes whose outcome flips from 17 to 0 (or 36 under the policy bit).
  Not machine-checked: the n-opcode/arbitrary-length scan induction (the
  scan is a fold of the same per-byte predicate), push-payload decode
  ordering and truncated pushes (F-DIV-001), the rest of
  ExecuteWitnessScript (initial stack size, 520-byte item cap, validation
  weight, annex/control block), and EvalScript after the disabled guard.
  The policy flag is modelled as bit 19 of the flag word; whether a node
  sets it is policy context outside the consensus rule.
patches: none
source_citations:
  - script.cpp:365-371 (IsOpSuccess)
  - interpreter.cpp:467-482 (the fifteen disabled opcodes, BASE/WITNESS_V0 arm)
  - interpreter.cpp:1846-1862 (tapscript OP_SUCCESSx pre-scan and policy arm)
  - interpreter.h:143-144 (SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS ordinal)
  - script/verify_flags.h:18-28 (name ordinal -> bit 1 << ordinal)
  - "BIP342: the fifteen disabled bytes are OP_SUCCESS126..OP_SUCCESS153"
  - Defs.lean:455-462 (disabledWire)
  - Defs.lean:463-466 (isOpSuccessWire)
  - Defs.lean:468-490 (opSuccessScanFrom / opSuccessScan)
  - Defs.lean:817-832 (stepBody: pushSize, opCount, disabledWire order)
  - Defs.lean:1207-1216 (executeWitnessScript tapscript arm)
  - Delta.lean:62-85 (TPR-061/TPR-062 success/discourage totality)
  - Delta.lean:98+ (TPR-074 every disabled wire is an OP_SUCCESSx)
  - Rules.lean:731-752 (SCR-172 fifteen-wire successx matrix)
trust_note: >
  C is a line-cited source-excerpt slice of Core, not the whole EvalScript or
  ExecuteWitnessScript: it models the disabled arm, IsOpSuccess, the one-byte
  pre-scan and its policy branch. L is a literal transcription of the pinned
  Lean definitions (disabledWire, isOpSuccessWire, opSuccessScan,
  stepBody's disabled arm, executeWitnessScript's tapscript arm); the twin's
  generated dispatch table has no pre-scan handler because the scan runs
  before EvalScript. Both are hand transcriptions, not generated twin code;
  a shared misreading of the two source tables is the known limit of a table
  cell. Alive2 checks C <=> L over symbolic bytes and flag words; SAW verifies
  each leg against an independent Cryptol predicate. No Core source patch is
  used. This is a bounded step cell, not a whole-Engine equivalence proof, and
  the policy error 36 is standardness, not a consensus disabled-opcode
  failure.
---
