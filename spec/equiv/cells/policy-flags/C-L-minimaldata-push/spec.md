---
# Cell policy-flags/C-L-minimaldata-push
cell: C-L-minimaldata-push
family: policy-flags
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: false
precondition: |
  - Scope: the push-minimality gate of EvalScript.  Core computes
    `bool fRequireMinimal = (flags & SCRIPT_VERIFY_MINIMALDATA) != 0;` at
    interpreter.cpp:442 and applies it at :487-491 to every *executed* push
    (`fExec && 0 <= opcode && opcode <= OP_PUSHDATA4`), via
    `CheckMinimalPush` (script.cpp:373-396).
  - Inputs: an arbitrary 64-bit flag word (MINIMALDATA = 0x40 is read),
    fExec (0/1), the push opcode (0x00..0x4e is a push; anything larger is not
    a push and the gate is not reached), the pushed data length (0..2**64-1)
    and the data's first byte (masked to 0..255).
  - `CheckMinimalPush` reads only the data length and the first byte; bytes
    after the first are never consulted, so (len, byte0, opcode) is the
    complete input of the predicate.
postcondition: |
  - fExec == 0 or opcode > OP_PUSHDATA4 (0x4e): 0 (the push branch is not
    entered; an unexecuted push is never minimality-checked).
  - otherwise, MINIMALDATA set and !CheckMinimalPush -> 25 SCRIPT_ERR_MINIMALDATA
  - otherwise -> 0
  with CheckMinimalPush exactly as script.cpp:373-396:
      len == 0                      -> opcode == OP_0 (0x00)
      len == 1 and 1 <= b0 <= 16    -> false
      len == 1 and b0 == 0x81       -> false
      len <= 75                     -> opcode == len
      len <= 255                    -> opcode == OP_PUSHDATA1 (0x4c)
      len <= 65535                  -> opcode == OP_PUSHDATA2 (0x4d)
      else                          -> true
scr_rows: SCR-177
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
  - "interpreter.cpp:442 (fRequireMinimal = flags & SCRIPT_VERIFY_MINIMALDATA)"
  - "interpreter.cpp:487-491 (executed-push branch; MINIMALDATA -> SCRIPT_ERR_MINIMALDATA)"
  - "script.cpp:373-396 (CheckMinimalPush)"
  - "script.h:607 (CheckMinimalPush declaration)"
  - "src/validation.cpp:2249-2288 (GetBlockScriptFlags never sets MINIMALDATA)"
  - "src/policy/policy.h:118-133 (MINIMALDATA is standard, not mandatory)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:529-539 (checkMinimalPush)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:838-843 (stepBody pushBytes arm: fExec/minimalData)"
  - "contract/error_enum.md:69 (25 SIG_MINIMALDATA)"

trust_note: >
  C is a line-cited source excerpt of interpreter.cpp:442/487-491 and
  script.cpp:373-396 at the pin; it is not the whole EvalScript.  L is a
  REVIEWED TRANSLITERATION of Bitcoin.Interpreter.checkMinimalPush and the
  stepBody pushBytes arm (Defs.lean:529-539, 838-843), not generated from
  twin/ops_ir.py.  No crypto, memory or hash is involved.  No Core patch is
  used.
scope: |
  FULL for SCR-177 as cited (push minimality).  The same flag also makes
  CScriptNum reject non-minimally encoded numbers (interpreter.cpp:442 feeds
  CScriptNum's fRequireMinimal); that numeric use is a separate numeric-family
  rule and is NOT claimed here.
---

## What this cell proves

The cell proves the complete MINIMALDATA push gate: for every (flag word,
fExec, opcode, data length, first data byte) the reported ordinal is
SCRIPT_ERR_MINIMALDATA exactly when the flag is set, the push is executed, the
opcode is a push opcode and `CheckMinimalPush` rejects the encoding.  This
includes the OP_1..OP_16 and OP_1NEGATE rules, the direct-push <= 75 rule, and
the PUSHDATA1/PUSHDATA2 boundaries at 255/65535.  MINIMALDATA is a standard-only
flag (`GetBlockScriptFlags` never sets it).


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
sets MINIMALDATA, and it is absent from MANDATORY_SCRIPT_VERIFY_FLAGS
(policy.h:104-113).  MINIMALDATA appears only in STANDARD_SCRIPT_VERIFY_FLAGS
(policy.h:118-133).  A non-minimal push is therefore relay-invalid, not
consensus-invalid.

