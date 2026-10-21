---
# Cell tapscript-reimport/C-L-tapscript-reimport
cell: C-L-tapscript-reimport
family: tapscript-reimport
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: true
precondition: |
  - Scope: the two consensus re-imports the row cites:
      * tapscript minimal-IF, interpreter.cpp:623-629 (inside the OP_IF/OP_NOTIF
        case), which runs *before* and independently of the witness-v0 MINIMALIF
        policy branch;
      * the implicit clean-stack check at the end of ExecuteWitnessScript,
        interpreter.cpp:1876-1878, which is shared by witness-v0 and tapscript.
  - Inputs: an arbitrary 64-bit flag word (in particular MINIMALIF = 0x2000 is
    free, and the roots show it is *not* consulted on these paths), the
    SigVersion (0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT; other values are the
    cell's out-of-domain guard), fExec (0/1), the OP_IF argument's length and
    first byte (masked to 0..255), and the final stack length.
  - The stack is non-empty and the conditional is balanced for the minimal-IF
    root; the final stack length is an input for the clean-stack root.
postcondition: |
  Root 1 (minimal-IF dispatch, total over sigversion):
    fExec == 0                                       -> 0
    SigVersion == TAPSCRIPT and (len > 1 or (len == 1 and b0 != 1))
                                                     -> 51 SCRIPT_ERR_TAPSCRIPT_MINIMALIF
    else SigVersion == WITNESS_V0 and MINIMALIF set and the same condition
                                                     -> 31 SCRIPT_ERR_MINIMALIF
    else                                             -> 0
    The tapscript arm precedes the v0 arm, so for TAPSCRIPT the answer is 51 for
    every flag word: the policy bit can neither enable nor disable it.
  Root 2 (clean-stack enforcement, total over sigversion):
    SigVersion in {WITNESS_V0, TAPSCRIPT} and final length != 1
                                                     -> 30 SCRIPT_ERR_CLEANSTACK
    SigVersion == BASE                               -> the SCR-180 policy gate
                                                        (not claimed here;
                                                        modelled only for contrast)
    and on the witness/tapscript arms the flag word is never read.
scr_rows: SCR-183
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
  - "interpreter.cpp:623-629 (SigVersion::TAPSCRIPT rejects a non-minimal OP_IF/NOTIF argument, before the policy branch)"
  - "interpreter.cpp:631-637 (the witness-v0 policy branch that the tapscript arm precedes)"
  - "interpreter.cpp:1876-1878 (ExecuteWitnessScript: scripts inside witness implicitly require cleanstack; shared by v0 and tapscript)"
  - "src/script/interpreter.h:117-125 (tapscript has minimal-IF automatically and does not depend on the flag)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags sets TAPROOT; MINIMALIF/CLEANSTACK are absent)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:882-887 (stepBody: tapscript minimal-IF arm before the v0 policy arm)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1237-1239 (executeWitnessScript implicit cleanstack, applies to both sigversions)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1431,1443 (the *policy* cleanstack gates, for contrast)"
  - "contract/error_enum.md:96,75 (51 SIG_TAPSCRIPT_MINIMALIF, 30 SIG_CLEANSTACK)"

trust_note: >
  C is a line-cited source excerpt of interpreter.cpp:623-637 and 1876-1878 at
  the pin; it is not the whole EvalScript and not the whole
  ExecuteWitnessScript.  L is a REVIEWED TRANSLITERATION of the stepBody
  OP_IF/OP_NOTIF dispatch (Defs.lean:878-891) and the executeWitnessScript tail
  (Defs.lean:1236-1239), not generated from twin/ops_ir.py.  No crypto is
  involved.  No Core patch is used.
scope: |
  FULL for SCR-183 as cited (both predicates are total over their declared
  domains), with an explicit boundary: the final stack length and the OP_IF
  argument are *inputs*, so the cell proves the flag-independent *enforcement*
  of both consensus rules, not that EvalScript computes that post-state.  The
  post-state derivation is the whole-engine loop seam (E4:F-TOOL-001) and is not
  claimed.  Tapscript validation-weight, OP_SUCCESSx and signature semantics are
  out of scope.
---

## What this cell proves

The cell proves both halves of the tapscript re-import.  Minimal-IF: for
SigVersion::TAPSCRIPT the OP_IF/OP_NOTIF argument must be the empty vector or
the single byte 0x01, else SCRIPT_ERR_TAPSCRIPT_MINIMALIF (51) - and the
tapscript arm runs before the witness-v0 MINIMALIF policy arm, so for every flag
word the tapscript answer is 51 (the policy bit can neither enable nor disable
it).  Clean-stack: the `stack.size() != 1 -> SCRIPT_ERR_CLEANSTACK` check at the
end of ExecuteWitnessScript is shared by witness-v0 and tapscript and reads no
policy bit at all.  Both are consensus rules; the rows' point is that neither
depends on the corresponding policy flag.


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

**Consensus.**  These two checks are unconditional in the interpreter, not
gated by a flag: `TAPROOT` is in `GetBlockScriptFlags`
(validation.cpp:2249-2288) and the tapscript minimal-IF/clean-stack behaviour
follows from the script version, not from MINIMALIF/CLEANSTACK (absent from that
function).  interpreter.h:117-125 states that tapscript has minimal-IF
"automatically ... and does not depend on this flag".  The row is filed
`consensus: true`.

