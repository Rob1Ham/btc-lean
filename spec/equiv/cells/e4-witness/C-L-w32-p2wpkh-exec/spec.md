---
# Cell e4-witness/C-L-w32-p2wpkh-exec
cell: C-L-w32-p2wpkh-exec
family: e4-witness
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (implied-script build -> GetOp decode -> five-op EvalScript -> witness tail, symbolic 160-bit program and symbolic hash/checksig seams)
precondition: |
  - Seam: the P2WPKH arm of VerifyWitnessProgram (interpreter.cpp:1947-1953)
    plus the ExecuteWitnessScript consumer (interpreter.cpp:1842-1879) and the
    five EvalScript iterations the implied script performs.  No transaction,
    no amount, no flags/policy word, no P2SH, no taproot, no whole-engine loop.
  - Inputs (all 64-bit words, all symbolic):
      p0,p1,p2      the 20-byte witness program (bytes 0..7, 8..15, 16..19;
                    p2 bits 32..63 do not reach any script byte);
      n_wit         witness stack size;
      sig_len       witness item 0 length (the signature);
      pk_len        witness item 1 length (the pubkey);
      h0,h1,h2      the modelled HASH160(pubkey) result, 20 bytes (hash seam);
      ck_err        modelled EvalChecksig ScriptError ordinal, low 6 bits
                    (signature/encoding/policy errors; 0 = no error);
      ck_ok         modelled EvalChecksig fSuccess when ck_err = 0.
  - h0..h2 and (ck_err, ck_ok) are *free inputs*: the cell assumes nothing
    about them and proves the execution outcome for every possible value.
    They are the declared same-hash / same-crypto seams (same value on both
    legs and in the Cryptol contract).  The residual obligation is to
    instantiate them with Core's CHash160 and EvalChecksig/EvalChecksigPreTapscript.
  - Bounded representation: script bytes are a pure selector over the 25-byte
    implied-script emission (no buffer/heap); the GetScriptOp walk and the
    EvalScript loop are unrolled exactly five times; stack elements are a
    20-byte payload window plus an explicit length, with the head slot as TOP.
    The contents of the signature and pubkey are opaque (the implied script
    copies the pubkey with OP_DUP and hands both items to the checksig seam;
    it never inspects their bytes); their lengths are exact and drive the
    <= 520-byte witness item cap.
  - Pushed payloads longer than 20 bytes are outside this leaf's payload
    window and take the out-of-domain arm; the only push the implied script
    performs is the 20-byte program.  The EvalScript terminal 1000-item
    STACK_SIZE guard is not modelled because depth never exceeds 4.
postcondition: |
  - Packed observable result(2) | error_ordinal(6) << 2, total over all inputs:
      n_wit != 2                                   -> (0, 40) WITNESS_PROGRAM_MISMATCH
      sig_len > 520 or pk_len > 520                -> (0,  6) PUSH_SIZE
      program != HASH160(pubkey) (20 bytes)        -> (0, 12) EQUALVERIFY
      program = HASH160(pubkey), ck_err != 0       -> (0, ck_err) the checksig ordinal
      program = HASH160(pubkey), ck_err = 0,
        ck_ok = 0                                  -> (0,  2) EVAL_FALSE
      otherwise                                    -> (1,  0) success
    with the ordering above (arity, witness item cap, then the script).
  - Converse forms are included: 40 iff n_wit != 2; 6 iff an item exceeds 520;
    12 iff the two 20-byte values differ; the checksig ordinal iff it is
    reached with ck_err != 0; 2 iff reached with a false checksig; 1 iff
    reached with a true checksig.
  - The proof starts from the constructed bytes: each leg builds
    76 a9 14 <program> 88 ac, decodes it with the GetOp rules (direct push,
    PUSHDATA1/2/4, push-number), asserts the walk ends exactly at byte 25, and
    executes the five decoded instructions with the EvalScript per-op checks
    (push size, 201-op budget, disabled-opcode table) and the OP_DUP /
    OP_HASH160 / OP_EQUAL(VERIFY) / OP_CHECKSIG(VERIFY) semantics, followed by
    the implicit witness cleanstack and CastToBool.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-136
scr_row_coverage: |
  partial — SCR-136, execution half, partial in the strict ledger sense but no longer a
  reconstruction-only row.

  Covered here (proved for every input, both directions):
  - the C and L implied-script byte emissions decode to exactly the five
    instructions OP_DUP, OP_HASH160, <20-byte program>, OP_EQUALVERIFY,
    OP_CHECKSIG and the walk ends at byte 25;
  - the five-step execution: DUP, HASH160 dispatch, EQUALVERIFY on the 20-byte
    values, CHECKSIG dispatch, and the ExecuteWitnessScript tail
    (cleanstack, CastToBool);
  - the P2WPKH arity predicate (n_wit = 2) and the witness item size cap;
  - total, converse-characterised outcome table above.
  Together with e4-witness/C-L-w32-p2wpkh-build (the byte reconstruction,
  still cited and unchanged) the row now reduces to two declared seams.

  NOT covered, and why the row stays partial:
  - HASH160 itself.  h0..h2 are universally quantified inputs; the proof is
    parametric, so it holds for the real CHash160, but it does not compute it.
    Closing this needs the hash floor (SCR-093/SCR-133 same-crypto boundary).
  - EvalChecksig (signature DER/hashtype/low-S/NULLFAIL checks and the ECDSA
    decision) at witness-v0.  ck_err/ck_ok are universally quantified inputs;
    the proof holds for the real checker but does not implement it.  This is
    the SCR-112/E3 crypto seam.
  - The generic EvalScript loop / arbitrary-script GetScriptOp walk, whole
    valtype/heap representation, script policy flags, and every other opcode.
    None is reachable from this fixed five-instruction script.
patches: none
source_citations:
  - interpreter.cpp:1947-1953 (v0 20-byte arm, arity != 2 -> 40, implied script, ExecuteWitnessScript)
  - interpreter.cpp:1842-1879 (ExecuteWitnessScript item cap, EvalScript, cleanstack, CastToBool)
  - interpreter.cpp:446-490 (EvalScript prologue; GetOp failure -> 16; push size; op budget; disabled table)
  - interpreter.cpp:803-812 (OP_DUP)
  - interpreter.cpp:896-925 (OP_EQUAL / OP_EQUALVERIFY, error 12)
  - interpreter.cpp:1032-1059 (OP_HASH160 dispatch point)
  - interpreter.cpp:1069-1088 (OP_CHECKSIG / OP_CHECKSIGVERIFY)
  - interpreter.cpp:46-59 (CastToBool)
  - script.cpp:313-363 (GetScriptOp; direct push, PUSHDATA1/2/4, truncation)
  - script.h:29,32 (MAX_SCRIPT_ELEMENT_SIZE = 520, MAX_OPS_PER_SCRIPT = 201)
  - script.h:408-431,470-488 (implied-script byte emission)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1259-1280 (Lean verifyWitnessProgram v0 arm)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1207-1236 (executeWitnessScript)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1163-1185 (evalScriptBytes)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1144-1152 (evalFrom)
  - spec/core/Bitcoin/Interpreter/Defs.lean:817-860,940-1010,1032-1059,1131-1142 (stepBody/stepChecked dispatch)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-231 (getOpAux/getOp)
  - spec/core/Bitcoin/Numeric/Interface.lean:64-65 (castToBool)
  - spec/equiv/contract/error_enum.md (ordinals 2, 6, 7, 12, 16, 18, 30, 40)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core at the pin, not the
  whole VerifyWitnessProgram and not the whole EvalScript: the implied script
  has five instructions, so the loop and the GetOp walk are unrolled five
  times.  L is a reviewed manual transliteration of the Lean step semantics
  (the twin has no ExecuteWitnessScript handler, so there is no generated body
  and no mk_leaf instance), with the Lean byte-list construction indexed
  directly.  The 20-byte payload window, the opaque sig/pubkey bytes, the pure
  byte selector in place of a std::vector, and the fixed policy/flags word are
  bounded-leaf representation choices, stated in the precondition; item
  lengths, the 520 cap, the 201-op budget, the disabled table, the error
  ordinals and the cleanstack/CastToBool predicates are exact.  HASH160 and
  EvalChecksig are not modelled: their results are free inputs, so no hash or
  signature-correction claim is made.  Alive2 compares the emitted C and L IR
  in both directions; SAW verifies each module against the same independent
  Cryptol postcondition with z3.  No Core source patch, no override and no
  assumption is used.
mutant: >
  Two one-line L-leg mutants were built and checked in scratch (notes.md §5):
  the PUSHDATA prefix 0x14 -> 0x13 and OP_DUP -> OP_DROP.  Alive2 reports
  "Transformation doesn't verify!" with a counterexample in both cases, so the
  cell constrains the build -> parse link and the stack semantics, not just the
  final predicate.
---
