---
# Cell exec-verify/C-L-w64-p2sh-subscript-leaf
cell: C-L-w64-p2sh-subscript-leaf
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (Alive2 and SAW) for the bounded subscript leaf; no whole-EvalScript claim
precondition: |
  - VerifyScript's P2SH arm at interpreter.cpp:2062-2105 has been entered and
    the redeem element has been identified (`exec-verify/C-L-p2sh-handoff`).
    This cell starts at the subscript call:
        swap(stack, stackCopy); pubKeySerialized = stack.back();
        CScript pubKey2(pubKeySerialized.begin(), pubKeySerialized.end());
        popstack(stack);                      // :2076-2078
        EvalScript(stack, pubKey2, ...)       // :2080
    The evaluated bytes ARE the last scriptSig stack element, so the input
    `ss_top` (length `ss_top_len`) is both the popped element and the script.
  - `ss_depth` = stackCopy.size() in 1..1000; `prev_top`/`prev_len` = the
    element below the redeem element, i.e. the top of the stack handed to
    EvalScript (0..8-byte element encoding). Elements below `prev_*` are not
    observable in this leaf because no in-domain instruction reads or pops
    them.
  - Flags: P2SH on, SCRIPT_VERIFY_MINIMALDATA off (no CheckMinimalPush),
    SIGPUSHONLY irrelevant here, SigVersion::BASE, no witness tail and no
    CLEANSTACK (other rows). scriptSig evaluation already succeeded.
  - LEAF SCRIPT DOMAIN (both legs return the out-of-model marker outside it):
    subscript length 0..2, i.e. at most one parsed instruction:
      len 0: empty script
      len 1: OP_0 (0x00), OP_1NEGATE (0x4f), OP_1..OP_16 (0x51..0x60),
             OP_RETURN (0x6a), 0x01..0x4e (truncated push/PUSHDATA)
      len 2: 0x01 b (direct 1-byte push), 0x4c 0x00 (PUSHDATA1 of zero
             bytes), 0x4c b>0, 0x02..0x4b, 0x4d, 0x4e (truncated)
    Every other byte is outside the cell. This is a declared bounded
    transcription of GetScriptOp + one EvalScript instruction, not the real
    EvalScript function.
postcondition: |
  Observable = packed (result, error_kind): result(2) | error_kind(6) << 2,
  error ordinals from contract/error_kind.h at the pin.

  Outside the guards (`ss_depth < 1`, `ss_depth > 1000`, `ss_top_len > 2`,
  `prev_len > 8`) or outside the leaf opcode set, both legs return
  (0, 1) UNKNOWN_ERROR as the out-of-model marker.

  In-domain, for every 64-bit input:
    ss_err is not an input here: the call is reached only after a successful
    scriptSig and scriptPubKey evaluation.
    empty script, ss_depth = 1            -> (0, 2)   EVAL_FALSE (empty stack)
    empty script, ss_depth > 1            -> CastToBool(prev) ? (1,0) : (0,2)
    OP_0, or PUSHDATA1-of-zero             -> (0, 2)  pushed empty element
    0x01 b                                -> b false/CastToBool -> (0,2) or (1,0)
    OP_1NEGATE / OP_1..OP_16              -> (1, 0)  pushed 0x81 / 0x01..0x10
    OP_RETURN                             -> (0, 3)  error from the call
    truncated push / PUSHDATA             -> (0, 16) BAD_OPCODE from GetOp
  The EVAL_FALSE checks (:2083-2086) are applied to the stack the bounded
  subscript evaluation returned, in Core's order (empty first, then
  CastToBool of the top element). The post-op stack-size check (:1231-1233)
  is carried in both legs but cannot fire for ss_depth <= 1000 (pop then at
  most one push is net zero).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-005
scr_row_coverage: >-
  partial. Proved by this cell: for the bounded leaf, the subscript
  EvalScript(pubKey2) call is no longer a symbolic outcome premise -- the
  call's script bytes are the last scriptSig stack element, the call's
  argument stack is stackCopy minus that element, and the two EVAL_FALSE
  checks at :2083-2086 are applied to the stack that the bounded evaluation
  actually returns (including the empty-stack arm and the CastToBool
  negative-zero arm), with BAD_OPCODE/OP_RETURN error propagation from the
  call. NOT proved and NOT claimed: the real EvalScript body over general
  scripts (E5 residual B1-B7: GetScriptOp over arbitrary buffers, the
  symbolic dispatch loop, heap, exceptions, guards, crypto), any script
  longer than 2 bytes or with more than one instruction, the 201-op/stack
  limits outside the leaf, MINIMALDATA, or the P2SH-wrapped witness tail.
  SCR-005 therefore remains partial: the shape predicate and handoff are
  proved elsewhere and this cell advances only the call/EVAL_FALSE boundary
  on an explicit leaf.
patches: none
source_citations: |
  - interpreter.cpp:2069-2086 (swap/restore, back(), CScript construction,
    popstack, subscript EvalScript call, EVAL_FALSE checks)
  - interpreter.cpp:449-494 (loop head, GetOp failure -> BAD_OPCODE, direct
    push at 488-492, dispatch switch entry at 494)
  - interpreter.cpp:499-523 (OP_1NEGATE / OP_1..OP_16 via CScriptNum,
    push at 519)
  - interpreter.cpp:677 (OP_RETURN -> SCRIPT_ERR_OP_RETURN)
  - interpreter.cpp:1231-1233 (post-op MAX_STACK_SIZE check)
  - script.cpp:313-363 (GetScriptOp operand decoding)
  - script.cpp:224-231 (IsPayToScriptHash, the arm's shape guard; other cell)
  - spec/core/Bitcoin/Interpreter/Defs.lean:421-431 (parseWire)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-230 (getOp/getOpAux)
  - spec/core/Bitcoin/Interpreter/Defs.lean:817-930 (stepBody push/OP_RETURN)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1131-1156 (stepChecked, evalFrom,
    finalStack)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1163-1171 (evalScriptBytes)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1327-1350 (p2shInner tail)
  - contract/error_enum.md:32,33,38,46 (ordinals 2 EVAL_FALSE, 3 OP_RETURN,
    8 STACK_SIZE, 16 BAD_OPCODE)
trust_note: >
  The C leg is a line-cited source-excerpt slice of Core at the pin, with the
  EvalScript loop unrolled to the single instruction the leaf permits; the L
  leg is a reviewed transliteration of Lean's parseWire/stepBody/evalFrom/
  p2shInner, using the Lean castToBool form and the combined
  `stack = [] ∨ !castToBool` predicate. The two legs are deliberately
  different programs (switch/phi vs parse record + one-step evaluator,
  Core vs Lean CastToBool), so Alive2 is a semantic comparison, and
  `--always-verify` forbids the syntactically-equal shortcut. The cell models
  EvalScript; it does NOT prove the real EvalScript body (E5 residual). The
  crypto seam is not touched: the HASH160 match that gates the arm is the
  other cells' premise and is not claimed here. No patch, no Lean edit.
mutant: |
  Executed (mutant/run.sh, raw output in mutant/result.txt), both caught by
  Alive2:
   M1 drop `popstack` (evaluate with the redeem element still on the stack):
      counterexample at the empty-script arm, where Core reads `prev` and the
      mutant reads the redeem element / keeps depth.
   M2 read the EVAL_FALSE element from the redeem bytes (`ss_top`) instead of
      the returned stack top: counterexample where prev is false and the
      redeem byte is truthy.
---

# exec-verify/C-L-w64-p2sh-subscript-leaf

Bounded two-leg cell for the P2SH subscript call and the EVAL_FALSE checks
(SCR-005), advancing the boundary left by
`exec-verify/C-L-w32-p2sh-23byte`, where the redeem-script EvalScript outcome
was a symbolic premise.

## Concrete Core differential (evidence, not proof)

`concrete/run.sh` links the local Core build at the pin and compares the C
model with the real `EvalScript` + the :2083-2086 checks over the whole leaf
byte space (all scripts of length 0, 1, 2) crossed with depth {1,2,3,12} and
seven `prev` elements covering the CastToBool arms:

```
checked=561848 skipped_out_of_model=1280356 mismatches=0
STATUS=core-differential-green
```

Skipped inputs are exactly the out-of-model marker cases (multi-instruction
scripts and opcodes outside the leaf). The raw log and the hashes of
`interpreter.cpp`, `script.cpp`, the consensus/secp256k1 libraries and both
sources are in `concrete/result.txt`. This is a finite differential, not a
refinement proof; it is what grounds the C transcription in real Core.

See `notes.md` for the exact commands, raw outcomes, mutant evidence and the
precise residual.
