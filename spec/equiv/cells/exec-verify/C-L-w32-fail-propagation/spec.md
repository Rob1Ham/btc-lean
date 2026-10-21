---
# Cell exec-verify/C-L-w32-fail-propagation
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-fail-propagation
family: exec-verify
tool_status: both-green (symbolic bounded model; see coverage)
precondition: |
  - The five VerifyScript engine calls are abstracted to their outcome:
    `scriptSig` EvalScript (e1), `scriptPubKey` EvalScript (e2), P2SH
    redeemScript EvalScript (e3), bare-witness VerifyWitnessProgram (ew1),
    P2SH-witness VerifyWitnessProgram (ew2), each (ok | fail, error).
  - Any 64-bit flag word; any error ordinal; any truth/path predicates
    (spk_truth, redeem_truth, bare_witness, p2sh_path, p2sh_redeem_witness,
    cleanstack_ok, witness_unexpected).
  - The stack, script contents, witness data and checker are NOT modeled;
    the path predicates stand in for the CScript::IsWitnessProgram /
    IsPayToScriptHash / scriptSig checks (other rows).
postcondition: |
  - `cell_fail_prop` returns the packed (result, error) of the VerifyScript
    early-return skeleton, in Core's order: a failing e1/e2/e3/ew1/ew2 at a
    reached call site returns result 0 with that call's error ordinal; no
    later code runs; success is 0x100.
  - `cell_prop_law` returns 1 for every input: a reachable EvalScript or
    VerifyWitnessProgram failure implies an invalid input.
  - Both legs agree on both functions for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-017
scr_row_coverage: |
  partial — the propagation combinator is proved for ALL symbolic engine
  outcomes, in Core's return order, including every early return named by
  interpreter.cpp:2029-2036/2052-2054/2080-2082/2097-2099. What is not
  proved: that Core's EvalScript/VerifyWitnessProgram actually return those
  outcomes (the E5 residual: GetScriptOp, heap, dispatch loop, exceptions),
  and the CScript::IsWitnessProgram / IsPayToScriptHash / scriptSig
  predicates are inputs. So the row is discharged at the wrapper seam only,
  not over real scripts.
patches: none
source_citations:
  - interpreter.cpp:2029-2036 (scriptSig and scriptPubKey EvalScript)
  - interpreter.cpp:2052-2054 (bare-witness VerifyWitnessProgram)
  - interpreter.cpp:2080-2082 (redeemScript EvalScript)
  - interpreter.cpp:2097-2099 (P2SH-witness VerifyWitnessProgram)
  - interpreter.cpp:2037-2040,2092-2095 (EVAL_FALSE tails)
  - interpreter.cpp:2107-2119,2121-2127 (CLEANSTACK, WITNESS_UNEXPECTED)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1363-1420 (verifyScriptFull)
  - spec/proofs/BitcoinProofs/AF/PDW62b/PDW62b.lean (row faces)
trust_note: >
  C is a line-cited slice of VerifyScript's control skeleton in which the
  five calls are stubbed to their (ok|fail, error) outcome. L is a reviewed
  hand transliteration of verifyScriptFull's match-on-VerifyOutcome shape
  (`Outcome {Ok,Fail}`); Lean's third constructor `.unjudged` is an
  out-of-seam outcome and is not modeled. Success/failure and error
  precedence are the whole observable; the cleanstack and unexpected-witness
  tails are included with abstracted conditions. No Core patch; no unsafe
  assume; no claim about real script execution or crypto.
---
