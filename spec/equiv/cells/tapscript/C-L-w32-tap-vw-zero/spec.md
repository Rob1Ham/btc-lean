---
# Cell tapscript/C-L-w32-tap-vw-zero
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
cell: C-L-w32-tap-vw-zero
family: tapscript
tool_status: both-green (symbolic over all 32-bit sizes and int64 budgets)
precondition: |
  - SigVersion::TAPSCRIPT; flags = 0 (in particular
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_PUBKEYTYPE is clear).
  - The signature and pubkey bytes are represented by their lengths
    (sig_len, pk_len); the Schnorr verdict is one symbolic boolean.
  - Budget domain: m_validation_weight_left is initialised at
    interpreter.cpp:1991 to GetSerializeSize(witness.stack) + 50, hence
    0 <= vw <= 4000050; the cell guards this range and returns the fixed
    marker 0xdeadbeef outside it (harness guard, documented in notes.md).
postcondition: |
  - Non-empty sig: vw' = vw - 50; if vw' < 0 the script fails with
    TAPSCRIPT_VALIDATION_WEIGHT (49). vw' == 0 continues (SCR-168).
  - Empty sig: no decrement, success = false, script continues.
  - pk_len == 0 fails with TAPSCRIPT_EMPTY_PUBKEY (52) after the budget
    step; pk_len == 32 with a false symbolic verdict fails with
    SCHNORR_SIG (47); other non-empty key versions continue.
  - Observable: bit0 continues, bits1..7 error, bit8 CHECKSIG success,
    bits16..47 the resulting budget as int32 two's complement.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-168
scr_row_coverage: full — the `< 0` (not `<= 0`) budget edge is evaluated
  over the whole reachable budget domain, including the exactly-zero case
  and the 0/-1 boundary; every branch of the cited Core slice is exercised
  (non-empty/empty sig, budget fail/pass, empty/32-byte/upgradable pubkey,
  Schnorr false/true).
patches: none
source_citations:
  - "interpreter.cpp:366 (success = !sig.empty())"
  - "interpreter.cpp:368-375 (decrement then `if (m_validation_weight_left < 0)`)"
  - "interpreter.cpp:376-388 (pubkey-size dispatch)"
  - "interpreter.cpp:1991-1992 (budget initialisation)"
  - "interpreter.h VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:90-93,757-779 (evalChecksigTapscript)"
  - "spec/core/Bitcoin/Interpreter/Rules.lean:467-477 (budget_exactly_zero)"
  - contract/error_kind.h:47,49,52
trust_note: >
  SAME-CRYPTO CONDITION: the Schnorr verdict is an unconstrained boolean in
  both legs; nothing here proves BIP340/secp256k1.  C is a line-cited slice
  of EvalChecksigTapscript, not the whole checker: the signature and pubkey
  byte strings are reduced to their lengths and the CScript/valtype
  machinery is not modelled.  L is a reviewed transliteration of the Lean
  equation; the Twin's generated op table has no tapscript CHECKSIG handler
  at model rev 4d62a97.  The range guard and the packed observable are cell
  harness.  Taproot key-path spending does not execute a script and is out
  of scope; SCR-159/160/041/042 branches are traversed but not claimed.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "change `< 0` to `<= 0` (reject an exactly-zero budget); expect both tools to fail on vw == 50"
mutant_site: "src/c_leaf.cpp / src/l_leaf.cpp budget comparison"
---

# Cell `tapscript/C-L-w32-tap-vw-zero`

SCR-168 says the BIP342 validation-weight budget may land exactly on 0.
Core checks `m_validation_weight_left < 0` (`interpreter.cpp:373`), so a
budget of 50 before the decrement is accepted and leaves 0.

`cell_eval_checksig` models the whole `EvalChecksigTapscript` decision
skeleton with `(sig_len, pk_len, vw, schnorr_ok)` symbolic. The row is a
pure integer predicate, so a symbolic check over the reachable budget
domain is a full check of the row, and the cell also pins the surrounding
ordering (budget check before pubkey checks).

Both tools are green; SAW verifies each leg against the independent
Cryptol rule, Alive2 compares the two modules.
