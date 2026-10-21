---
# Cell limits/C-L-sigop-site-weights
cell: C-L-sigop-site-weights
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic, all 256 x 256 opcode pairs x both modes)
precondition: |
  - The cell is one iteration of CScript::GetSigOpCount's loop body
    (script.cpp:159-181): the per-site contribution, not the script walk.
  - `lastOpcode` is the `opcodetype` carried from the previous iteration.
    It is a wire byte: OP_INVALIDOPCODE (0xff) before the first site, and
    any decoded opcode byte afterwards. All 256 values are in the domain.
  - `opcode` is the current decoded opcodetype, all 256 values.
  - `fAccurate` is Core's bool; its domain is {0,1}. Non-zero bytes follow
    the same branch in both legs (the cell is total there, but only 0/1 is
    a Core flag value).
  - The script walk (which sites exist, malformed-push termination) is not
    part of this cell; it belongs to SCR-034/045.
postcondition: |
  - Returns the loop-body contribution n in 0..20:
      opcode = 0xac or 0xad (CHECKSIG / CHECKSIGVERIFY)       -> 1
      opcode = 0xae or 0xaf (CHECKMULTISIG / ...VERIFY):
        fAccurate && lastOpcode in 0x51..0x60 (OP_1..OP_16)   -> lastOpcode - 0x50  (1..16)
        otherwise                                             -> 20 (MAX_PUBKEYS_PER_MULTISIG)
      every other opcode                                      -> 0
  - Equality is exact, including the 0xff initial `lastOpcode` falling into
    the 20 arm.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-032, SCR-033
scr_row_coverage: |
  full for both rows:
  - SCR-032 (CHECKSIG=1; CHECKMULTISIG=20 inaccurate): full. The inaccurate
    arm is proved for every (lastOpcode, opcode) pair in 0..255: all four
    sigop opcodes and every non-sigop opcode. The inaccurate mode never reads
    lastOpcode, as in Core.
  - SCR-033 (accurate CHECKMULTISIG counts the immediately preceding
    OP_1..OP_16 value, else 20, at each site): full. For every preceding
    opcodetype and every current opcode, the accurate arm charges
    DecodeOP_N(prev) exactly when prev is a direct OP_1..OP_16 push
    (0x51..0x60) and 20 otherwise. "At each site" is the row's wording; the
    walk that enumerates the sites is not part of this row (see SCR-034/045).
  Out of scope: the aggregation over a script (SCR-034/045) and the
  truncated-push termination of the static walk.
patches: none
source_citations:
  - script.cpp:159-181 (CScript::GetSigOpCount false/true arms)
  - script.cpp:168 (CHECKSIG / CHECKSIGVERIFY increment)
  - script.cpp:173-177 (accurate lookback / MAX_PUBKEYS_PER_MULTISIG fallback)
  - script.h:35 (MAX_PUBKEYS_PER_MULTISIG = 20)
  - opcode.h:83-87,100-102 (OP_1=0x51 .. OP_16=0x60; CHECKSIG..CHECKMULTISIGVERIFY 0xac..0xaf)
  - spec/core/Bitcoin/Interpreter/SigOps.lean (sigOpStep, opNumberOf, isCheckSigWire, isCheckMultiSigWire)
trust_note: >
  C is a line-cited source-excerpt slice of script.cpp at the pin, not the
  whole GetSigOpCount loop. L is a reviewed transliteration of the twin's
  sigOpStep/opNumberOf (SigOps.lean); the twin has no C-emitted handler for
  static sigop counting, so this is a manual, reviewable transliteration.
  Alive2 compares the two IR functions over every i8 pair and the mode byte;
  SAW verifies each module against the independent Cryptol predicate. The
  cell proves the per-site weight rule only; it does not prove the script
  walk or truncation behaviour. No Core patch is used.
mutant: >
  Proposed, not executed: drop the `lastOpcode >= OP_1` half of the accurate
  lookback, so OP_0/OP_1NEGATE illegally contribute DecodeOP_N. Expected:
  Alive2 counterexample at lastOpcode = 0x00 with opcode = 0xae (C = 20,
  L = 0); SAW failure.
---
