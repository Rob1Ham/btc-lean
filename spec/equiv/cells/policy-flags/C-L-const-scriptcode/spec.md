---
# Cell policy-flags/C-L-const-scriptcode
cell: C-L-const-scriptcode
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: the two CONST_SCRIPTCODE gates the row cites:
      * the decode-time rejection of OP_CODESEPARATOR in a BASE script,
        interpreter.cpp:484-486;
      * the FindAndDelete rejection in `EvalChecksigPreTapscript`,
        interpreter.cpp:339-343.
  - Inputs: an arbitrary 64-bit flag word (CONST_SCRIPTCODE = 0x10000 is
    read), the SigVersion (0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT), whichever
    of (opcode, FindAndDelete count) the root needs, and a 0/1 model of
    `found > 0`.
  - Preconditions: for the decode root, the earlier decode/opcount/disabled
    checks passed (they precede :485); for the FindAndDelete root, the
    signature element is whatever was searched for and `found` is its
    FindAndDelete count, with count 0 or 1 modelled exactly (a 1-bit input; the
    greedy scan can return more, but the rule only tests `found > 0`).
postcondition: |
  Root 1 (decode):
    opcode == OP_CODESEPARATOR (0xab) and SigVersion == BASE and flag set
      -> 53 SCRIPT_ERR_OP_CODESEPARATOR
    otherwise -> 0.  It fires even in an unexecuted branch, because :485 runs
    before the fExec switch.
  Root 2 (FindAndDelete):
    SigVersion == BASE and found > 0 and flag set
      -> 54 SCRIPT_ERR_SIG_FINDANDDELETE
    otherwise -> 0.  Witness v0 keeps the signature in scriptCode (BIP143), so
    FindAndDelete never runs there and the gate cannot fire.
scr_rows: SCR-181
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
  - "interpreter.cpp:484-486 (OP_CODESEPARATOR + BASE + CONST_SCRIPTCODE -> SCRIPT_ERR_OP_CODESEPARATOR, before the fExec dispatch)"
  - "interpreter.cpp:1058-1066 (OP_CODESEPARATOR case in the executed switch)"
  - "interpreter.cpp:332-343 (FindAndDelete only for SigVersion::BASE; found>0 && CONST_SCRIPTCODE -> SCRIPT_ERR_SIG_FINDANDDELETE)"
  - "src/script/interpreter.h:127-133 (CONST_SCRIPTCODE: OP_CODESEPARATOR and FindAndDelete fail non-segwit scripts)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets CONST_SCRIPTCODE)"
  - "src/policy/policy.h:118-133 (CONST_SCRIPTCODE is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:833 (stepBody decode-time OP_CODESEPARATOR gate)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:725-729 (evalChecksigPreTapscript FindAndDelete gate)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1098-1101 (scriptCode FindAndDelete gate in the checksig path)"
  - "contract/error_enum.md:98-99 (53 SIG_OP_CODESEPARATOR, 54 SIG_FINDANDDELETE)"

trust_note: >
  C is a line-cited source excerpt of the two gates (interpreter.cpp:484-486,
  332-343) at the pin; it is not the whole EvalScript and does not implement
  FindAndDelete itself.  L is a REVIEWED TRANSLITERATION of the corresponding
  stepBody and evalChecksigPreTapscript gates (Defs.lean:833, 725-729), not
  generated from twin/ops_ir.py.  The FindAndDelete count is an input; the scan
  algorithm is a separate rule and is not claimed.  No Core patch is used.
scope: |
  FULL for SCR-181 as cited (:484-486, :339-343): both gates are total over
  (flag word, sigversion, opcode) and (flag word, sigversion, found>0).  NOT
  claimed: the byte-level FindAndDelete implementation/comparison
  (Defs.lean:541-600) and the scriptCode slicing at the last separator; only
  the flag gates are proved.
---

## What this cell proves

The cell proves both halves of CONST_SCRIPTCODE: on a BASE script, an
OP_CODESEPARATOR is rejected at decode time even when it sits in an unexecuted
branch, and a signature found by FindAndDelete rejects the spend with
SCRIPT_ERR_SIG_FINDANDDELETE.  Both are gated by the flag and by
`sigversion == BASE`; witness v0 and tapscript are untouched (BIP143 removed
FindAndDelete there), which the same total predicate shows.


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
sets CONST_SCRIPTCODE, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  It appears only in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133), where interpreter.h:127-133 describes it as making
OP_CODESEPARATOR/FindAndDelete fail non-segwit scripts for standardness.

