---
# Cell exec-verify/C-L-w32-witness-flag
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: exec-verify/C-L-w32-witness-flag
family: exec-verify
tool_status: both-green
precondition: |
  - Base sigversion. scriptPubKey is empty. P2SH is active.
  - scriptSig = the declared seam: EvalScript(scriptSig) either fails with a
    symbolic ordinal `ss_err`, or succeeds leaving exactly one truthy element
    (the row's hypothesis; the empty scriptPubKey evaluation is the identity
    on that stack, PDW90.lean:15-18).
  - `witness` (SCRIPT_VERIFY_WITNESS) and `cleanstack`
    (SCRIPT_VERIFY_CLEANSTACK) are symbolic; `witness_nonempty` says whether
    the transaction's witness stack is non-null.
  - CLEANSTACK without WITNESS is outside the domain: Core asserts
    (`assert((flags & SCRIPT_VERIFY_WITNESS) != 0)`, interpreter.cpp:2113).
    Both legs return UNKNOWN for that combination instead of modelling an
    abort.
postcondition: |
  - result(2) | error_kind(6) << 2 is:
      ss_err != 0                             -> (0, ss_err)
      cleanstack set, witness clear           -> (0, 1)   declared guard
      witness set, witness non-empty          -> (0, 43)  WITNESS_UNEXPECTED
      otherwise                               -> (1, 0)   success
  - With WITNESS off the empty-scriptPubKey spend validates, and with WITNESS
    on a non-empty witness it fails WITNESS_UNEXPECTED, because an empty
    scriptPubKey is not a witness program. This holds with CLEANSTACK set as
    well: the one-element stack passes the cleanstack check
    (interpreter.cpp:2115-2118), which the row notes was previously unproved.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-004
scr_row_coverage: >-
  full for the row: WITNESS off -> success; WITNESS on + empty witness ->
  success; WITNESS on + non-empty witness -> WITNESS_UNEXPECTED (43), each
  also with CLEANSTACK on (the one-element cleanstack arm the row says was
  unproved); SIGPUSHONLY off is the declared flag context. The scriptSig
  evaluation outcome and the empty-script identity remain the row's
  hypotheses, as in the Lean face PDW90.verifyScriptFull_empty_spk.
patches: none
source_citations:
  - interpreter.cpp:2037-2040 (empty/false top -> EVAL_FALSE)
  - interpreter.cpp:2045-2059 (bare witness program block; empty spk is not one)
  - interpreter.cpp:2062-2105 (P2SH block; empty spk is not P2SH)
  - interpreter.cpp:2106-2118 (CLEANSTACK asserts and stack.size() == 1)
  - interpreter.cpp:2120-2128 (WITNESS_UNEXPECTED for no witness program)
  - twin/runtime.inc:806-841 (twin witness/cleanstack tails)
  - Defs.lean:1386-1396, 1443-1446 (bare witness + cleanstack/witness tails)
  - spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:20-34, 69-84
    (verifyScriptFull_empty_spk, verifyScriptFull_witness_unexpected)
  - contract/error_enum.md:78 (ordinal 43 WITNESS_UNEXPECTED)
trust_note: >
  Script evaluation is the declared seam of the row face; the empty
  scriptPubKey evaluation is the identity (Lean evalScriptBytes_empty). The C
  leg follows Core's hadWitness branch order (witness programs before P2SH,
  cleanstack before the unexpected-witness tail); the L leg follows the
  twin's flat order. Both tools prove agreement, and SAW proves each leg
  against the row's postcondition. No Core patch; no crypto.
mutant: >
  Proposed, not executed: in the L leg, test `witness_nonempty` without
  `witness` (fail whenever a witness is present). Expected Alive2
  counterexample at witness = 0, witness_nonempty = 1 (C = success).
---
