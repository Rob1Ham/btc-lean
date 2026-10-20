---
# Cell limits/C-L-cms-count-bounds
cell: C-L-cms-count-bounds
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic bounded predicate, both directions)
precondition: |
  - The cell is the OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY limit prefix
    only (interpreter.cpp:1127-1142). It does not run the signature loop,
    the stack-size underflow checks, or the P2SH/FindAndDelete tail.
  - `nKeysCount` and `nSigsCount` are the already-decoded `int` values of
    `CScriptNum(stacktop(-i), fRequireMinimal).getint()` (Core declares
    `int nKeysCount` / `int nSigsCount`). The CScriptNum decode (width and
    minimality) is a numeric-family row and is out of scope here.
  - `nOpCountIn` is Core's EvalScript-local `nOpCount` on entry to the
    opcode. It ranges over 0..201: this is the invariant maintained by the
    per-opcode check at interpreter.cpp:459-463 (the counter starts at 0,
    only increases, and each increase is checked immediately).
  - The operand stack is assumed to hold the CMS layout; the
    `INVALID_STACK_OPERATION` checks between the limits are not part of
    SCR-026/027/028.
  - Both counters are signed 32-bit; the op-count accumulator is Core's
    `int`, not a widened integer.
postcondition: |
  - Packed observable `result(2) | error(6) << 2 | nOpCount_after(32) << 8`:
      nKeysCount < 0 or > 20            -> (0, 10 PUBKEY_COUNT), nOpCount_after = nOpCountIn
      nOpCountIn + nKeysCount > 201     -> (0,  7 OP_COUNT),     nOpCount_after = nOpCountIn + nKeysCount
      nSigsCount < 0 or > nKeysCount    -> (0,  9 SIG_COUNT),    nOpCount_after = nOpCountIn + nKeysCount
      otherwise                         -> (1,  0 pass),         nOpCount_after = nOpCountIn + nKeysCount
  - The check order is Core's order: key count, then op count, then sig
    count. On the PUBKEY_COUNT edge the increment has not executed, so the
    pre-value is observable.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-026, SCR-027, SCR-028
scr_row_coverage: |
  full for all three rows, with the decode boundary stated:
  - SCR-026: full. The predicate `nKeysCount < 0 || nKeysCount > 20` is
    proved for every signed 32-bit nKeysCount, which is Core's `int` domain.
    No value of the decoded counter is excluded.
  - SCR-027: full. The predicate `nSigsCount < 0 || nSigsCount > nKeysCount`
    is proved for every signed 32-bit pair consistent with a validated key
    count (0..20); no sig-count value is excluded.
  - SCR-028: full. `nOpCount += nKeysCount` and the `> 201` rejection are
    proved for every nOpCountIn in the EvalScript invariant 0..201 and every
    accepted key count 0..20, and the incremented value is observable.
  Out of scope (separate rows): CScriptNum width/minimality decoding
  (SCR-079/080-family), operand-stack underflow, and the remaining CMS
  verification loop.
patches: none
source_citations:
  - interpreter.cpp:1120-1142 (CMS count decode, PUBKEY_COUNT, nOpCount +=, OP_COUNT, SIG_COUNT)
  - interpreter.cpp:459-463 (per-opcode nOpCount check that maintains 0..201)
  - script.h:30-35 (MAX_OPS_PER_SCRIPT = 201; MAX_PUBKEYS_PER_MULTISIG = 20)
  - script.h:246-271 (CScriptNum width/minimality; decode taken as input)
  - contract/error_kind.h:34,36,37 (OP_COUNT=7, SIG_COUNT=9, PUBKEY_COUNT=10)
  - spec/core/Bitcoin/Interpreter/Defs.lean:72,76 (MAX_OPS_PER_SCRIPT, MAX_PUBKEYS_PER_MULTISIG)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1071-1088 (checkMultiSig limit prefix)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp at the pin, not
  the whole EvalScript. L is a reviewed transliteration of the twin's
  checkMultiSig limit prefix (Defs.lean:1071-1088); the twin generator has
  no CMS-count handler, so this is a manual, reviewable transliteration, not
  generated IR. Both legs keep Core's `int` width for the counters. Alive2
  compares the two IR functions directly for every i32 input; SAW verifies
  each module against the independent Cryptol predicate under the stated
  nOpCount precondition. No Core patch is used. The cell proves the bounded
  limit arithmetic, not signature checking or the whole OP_CHECKMULTISIG.
mutant: >
  Proposed, not executed: change the PUBKEY_COUNT edge from `> 20` to
  `>= 20`. Expected: Alive2 counterexample at nKeysCount = 20 (C passes,
  L returns PUBKEY_COUNT); SAW predicate failure. This is the limit-row
  analogue of the CMS family mutation.
---
