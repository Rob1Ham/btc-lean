---
# Cell policy-flags/C-L-minimalif-v0
cell: C-L-minimalif-v0
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: the witness-v0 policy arm of OP_IF/OP_NOTIF, interpreter.cpp:631-637.
  - Inputs: an arbitrary 64-bit flag word (MINIMALIF = 0x2000 is read), the
    SigVersion (0 = BASE, 1 = WITNESS_V0; every other value is the cell's
    out-of-domain guard), fExec (0/1), the top stack element's length
    (0..2**64-1) and its first byte (masked to 0..255).
  - The stack is non-empty and the branch is balanced (the underflow and
    UNBALANCED_CONDITIONAL paths are different rules).
  - The TAPSCRIPT arm (:624-629, SCRIPT_ERR_TAPSCRIPT_MINIMALIF) is deliberately
    excluded here; it is SCR-183's cell.
postcondition: |
  - fExec == 0                                   -> 0 (OP_IF not executed; no check)
  - SigVersion == WITNESS_V0 and MINIMALIF set and
    (len > 1 or (len == 1 and b0 != 1))           -> 31 SCRIPT_ERR_MINIMALIF
  - SigVersion == BASE                          -> 0 (the policy bit is ignored)
  - otherwise                                   -> 0
  i.e. the empty vector and the one-byte 0x01 vector pass; anything else fails
  only under the WITNESS_V0 + MINIMALIF combination.
scr_rows: SCR-178
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
  - "interpreter.cpp:625-644 (OP_IF/OP_NOTIF case; fExec gate :629, witness-v0 MINIMALIF :631-637, CastToBool :638)"
  - "src/script/interpreter.h:119-125 (MINIMALIF: segwit script only, tapscript re-imports it automatically)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets MINIMALIF)"
  - "src/policy/policy.h:118-133 (MINIMALIF is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:878-891 (stepBody OP_IF/OP_NOTIF; v0 arm :885-887)"
  - "contract/error_enum.md:76 (31 SIG_MINIMALIF)"

trust_note: >
  C is a line-cited source excerpt of the OP_IF/OP_NOTIF case at the pin; it is
  not the whole EvalScript.  L is a REVIEWED TRANSLITERATION of the stepBody
  OP_IF/OP_NOTIF equation (Defs.lean:878-891), not generated from
  twin/ops_ir.py.  No crypto, memory or hash is involved.  No Core patch is
  used.
scope: |
  FULL for SCR-178 as cited (:631-637): the v0 witness policy arm and the fact
  that BASE ignores the flag are total over (flags, sigversion in {BASE,
  WITNESS_V0}, fExec, element length, first byte), which is the complete input of
  the predicate.  Tapscript's consensus re-import is SCR-183 and is not claimed
  here.
---

## What this cell proves

The cell proves that MINIMALIF is a witness-v0-only policy gate: under
WITNESS_V0 with the bit set, an OP_IF/OP_NOTIF argument that is not exactly the
empty vector or the single byte 0x01 yields SCRIPT_ERR_MINIMALIF (31); with the
bit clear, or in a BASE script, the same argument is accepted.  The flag never
reaches block validation (`GetBlockScriptFlags`), so this is policy, not
consensus.


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

**Not consensus for v0.**  `GetBlockScriptFlags` (validation.cpp:2249-2288)
never sets MINIMALIF, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  interpreter.h:119-125 documents that tapscript re-imports
minimal-IF *as a consensus rule*; that arm is SCR-183 (consensus: true) and is a
different cell.

