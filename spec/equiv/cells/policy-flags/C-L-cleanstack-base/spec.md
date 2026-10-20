---
# Cell policy-flags/C-L-cleanstack-base
cell: C-L-cleanstack-base
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: the two clean-stack enforcement sites the row distinguishes:
      * base (non-witness) spends: the SCRIPT_VERIFY_CLEANSTACK gate at the end
        of VerifyScript, interpreter.cpp:2110-2118;
      * witness-v0 spends: the implicit check at the end of
        ExecuteWitnessScript, interpreter.cpp:1876-1878.
  - Inputs: an arbitrary 64-bit flag word (CLEANSTACK = 0x100 is read on the
    base path and never on the witness path), the SigVersion (0 = BASE,
    1 = WITNESS_V0; other values are the cell's out-of-domain guard) and the
    final stack length (0..2**64-1) handed to the check.
  - The P2SH/witness preconditions Core asserts at :2112-2114
    (CLEANSTACK => P2SH && WITNESS) are a flag-combination rule
    (Defs.lean Rules.flagsComboOk, SCR-009/SCR-014); they are not modelled as a
    root here, so the cell assumes a well-formed flag word.
  - The stack length is an input: the cell proves the enforcement predicate, not
    the interpreter loop that computes the stack.
postcondition: |
  - SigVersion == BASE:
      CLEANSTACK set and final length != 1 -> 30 SCRIPT_ERR_CLEANSTACK
      CLEANSTACK clear                     -> 0 (any length)
  - SigVersion == WITNESS_V0:
      final length != 1                    -> 30 SCRIPT_ERR_CLEANSTACK,
                                              regardless of the flag word
  - The witness arm runs before the EVAL_FALSE check (:1879), so a length of 0
    or >= 2 reports CLEANSTACK rather than EVAL_FALSE.
scr_rows: SCR-180
scr_row_coverage: full
coverage: full
patches: none
direction:
  - L ⊑ C
  - C ⊑ L
evidence:
  - alive2/result.txt, alive2/certificate.sha256 (raw alive-tv v20 output, both directions)
  - saw/result.txt, saw/certificate.sha256 (raw SAW 1.6 output, both legs)
  - ir/ (c_leaf.ll, l_leaf.ll, per-root extracted modules, build.txt; tracked, so the
    certificates hash exactly the modules presented to alive-tv/SAW)
  - findings/wave16/13-policy-reimport/tools/concrete_check.out (hand-computed
    behavioural vectors, C leg == L leg == expectation)
source_citations:
  - "interpreter.cpp:2109-2119 (VerifyScript tail: CLEANSTACK gate, asserts P2SH+WITNESS at :2112-2114, size != 1 -> SCRIPT_ERR_CLEANSTACK)"
  - "interpreter.cpp:2098-2107 (P2SH/witness path resizes the stack to 1 to bypass the check)"
  - "interpreter.cpp:1876-1878 (ExecuteWitnessScript: scripts inside witness implicitly require cleanstack)"
  - "src/script/interpreter.h:91-99 (CLEANSTACK: policy bit; WITNESS_V0/TAPSCRIPT have similar behaviour as consensus, automatic there)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets CLEANSTACK)"
  - "src/policy/policy.h:118-133 (CLEANSTACK is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1237-1239 (executeWitnessScript implicit cleanstack)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1431,1443 (VerifyScript pol.cleanstack gates on the P2SH and bare paths)"
  - "spec/core/Bitcoin/Interpreter/Rules.lean:45-52 (flagsComboOk: CLEANSTACK => P2SH && WITNESS)"
  - "contract/error_enum.md:75 (30 SIG_CLEANSTACK)"

trust_note: >
  C combines two line-cited excerpts of interpreter.cpp at the pin (2110-2118
  and 1876-1878); it is not the whole VerifyScript or ExecuteWitnessScript.  L is
  a REVIEWED TRANSLITERATION of executeWitnessScript's tail
  (Defs.lean:1237-1239) and the VerifyScript `pol.cleanstack` gates
  (Defs.lean:1431/1443), not generated from twin/ops_ir.py.  The final stack
  length is an input, so the cell is a predicate proof about *enforcement*; it
  does not model EvalScript.  No crypto is involved and no Core patch is used.
scope: |
  FULL for SCR-180 as cited (:2110-2118) plus the row's witness-v0 half
  (:1876-1878): total over (flag word, sigversion in {BASE, WITNESS_V0}, final
  length).  NOT claimed: that the final length is what EvalScript produces (that
  is the whole-engine loop seam, E4:F-TOOL-001), the P2SH `stack.resize(1)`
  bypass in detail, and the tapscript instance of the implicit check (SCR-183).
---

## What this cell proves

The cell proves the row's central distinction in one total predicate: on a
BASE spend the clean-stack requirement is *gated* by the CLEANSTACK policy bit,
while on a WITNESS_V0 spend the same `stack.size() != 1 -> CLEANSTACK`
requirement is enforced regardless of the flag word, because it sits in
`ExecuteWitnessScript` as a consensus rule.  It also fixes the error precedence:
the witness clean-stack check runs before EVAL_FALSE, so an empty or
multi-element witness script stack reports CLEANSTACK (30), not EVAL_FALSE.


## Both-tool evidence

- Alive2 (`alive2/result.txt`): every root compared in **both** directions
  (`alive-tv c_<fn>.ll l_<fn>.ll` for L ⊑ C and `alive-tv l_<fn>.ll c_<fn>.ll`
  for C ⊑ L); all report `Transformation seems to be correct!` /
  `1 correct transformations, 0 incorrect, 0 failed-to-prove`.
- SAW (`saw/result.txt`): every root verified in the C module and in the L
  module against the *same* Cryptol function in `saw/cell.cry`, which is written
  from the row's rule and is independent of both C++ files.
- Both `certificate.sha256` files verify with `sha256sum -c` from the repo root.

## Consensus status

**Mixed, and the row is non-consensus as stated.**  The CLEANSTACK *flag* is
policy: `GetBlockScriptFlags` (validation.cpp:2249-2288) never sets it, it is
absent from MANDATORY_SCRIPT_VERIFY_FLAGS (policy.h:104-113) and present in
STANDARD_SCRIPT_VERIFY_FLAGS.  The *witness-v0* clean-stack requirement is
consensus and independent of the flag (it lives in ExecuteWitnessScript).  The
row is filed `consensus: false` because the flag itself is policy; the cell
keeps the two halves separate so neither is overclaimed.  Tapscript's instance
is SCR-183 (consensus: true).

