---
# Cell policy-flags/C-L-nullfail
cell: C-L-nullfail
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: the NULLFAIL check of `EvalChecksigPreTapscript`,
    interpreter.cpp:351-352.
  - Inputs: an arbitrary 64-bit flag word (NULLFAIL = 0x4000 is read), the
    ECDSA verdict of the shared checker (0 = failure, non-zero = success) and
    the signature element's length (0..2**64-1).
  - The two encoding gates at :344-350 (CheckSignatureEncoding /
    CheckPubKeyEncoding) are discharged by the precondition: the cell models the
    path where they pass, which is the only path that reaches the NULLFAIL
    branch.
  - The ECDSA verdict is an input (SAME-CRYPTO): the cell proves the flag gate
    and its predicate, not ECDSA.
postcondition: |
  - verdict == failure and NULLFAIL set and sig.size() != 0
        -> 32 SCRIPT_ERR_SIG_NULLFAIL
  - otherwise -> 0
  In particular: an empty signature never trips NULLFAIL (Core's
  `&& vchSig.size()`), and with the flag clear a failed CHECK(MULTI)SIG pushes
  false instead of failing the script.
scr_rows: SCR-179
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
  - "interpreter.cpp:328-368 (EvalChecksigPreTapscript; encoding gates :344-350, checker call :349)"
  - "interpreter.cpp:351-352 (if (!fSuccess && (flags & SCRIPT_VERIFY_NULLFAIL) && vchSig.size()) -> SCRIPT_ERR_SIG_NULLFAIL)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets NULLFAIL)"
  - "src/policy/policy.h:118-133 (NULLFAIL is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:720-739 (evalChecksigPreTapscript; NULLFAIL :738)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:187-205 (PolicyFlags.nullFail)"
  - "contract/error_enum.md:77 (32 SIG_NULLFAIL)"

trust_note: >
  C is a line-cited source excerpt of interpreter.cpp:344-354 at the pin; it is
  not the whole EvalScript and not the whole checksig path.  L is a REVIEWED
  TRANSLITERATION of Bitcoin.Interpreter.evalChecksigPreTapscript
  (Defs.lean:720-739), not generated from twin/ops_ir.py.  The ECDSA verdict is
  an unconstrained input, so the cell is conditional on the shared checker:
  docs/DECISION-lax-ecdsa.md governs, and nothing here proves ECDSA or
  libsecp256k1.  No Core patch is used.
scope: |
  FULL for SCR-179 as cited (:351-352): total over (flag word, checker verdict,
  signature length).  NOT claimed: the second NULLFAIL site in the
  CHECKMULTISIG cleanup loop (interpreter.cpp:1212-1221,
  Defs.lean:702-712) - it is outside this row's cited range and is a
  CHECKMULTISIG-family rule.
---

## What this cell proves

The cell proves the NULLFAIL policy branch exactly: a failed CHECK(MULTI)SIG
with a non-empty signature element aborts with SCRIPT_ERR_SIG_NULLFAIL (32) only
when the NULLFAIL bit is set; an empty signature is exempt; and with the bit
clear the interpreter returns false to the script instead of failing it.
NULLFAIL is standard-only (`GetBlockScriptFlags` never sets it).


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

**Not consensus.**  `GetBlockScriptFlags` (validation.cpp:2249-2288) never
sets NULLFAIL, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  It appears only in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133).  A non-empty failed signature is therefore relay-invalid,
not consensus-invalid.

