---
# Cell exec-verify/C-L-w32-p2sh-23byte
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: exec-verify/C-L-w32-p2sh-23byte
family: exec-verify
tool_status: both-green
precondition: |
  - Base sigversion; P2SH active. Two functions are proved:
    1. `cell_is_p2sh(len, b0, b1, b22)`: the 23-byte template test over a
       symbolic script length and symbolic bytes at offsets 0, 1 and 22.
    2. `cell_p2sh_reeval(...)`: VerifyScript's P2SH arm given the
       post-scriptSig stack `(depth, top, top_len)`, a symbolic hash-equality
       `hash_match` (HASH160(redeemScript) == the committed 20-byte hash, the
       crypto seam), a symbolic push-only bit for scriptSig, and the symbolic
       redeem-script EvalScript outcome `(redeem_err, redeem_depth,
       redeem_top, redeem_top_len)`.
  - Domain: element encodings <= 8 bytes; both legs return UNKNOWN outside.
    `ss_depth > 0` is required for the P2SH arm; depth 0 is the
    OP_HASH160 underflow arm (18).
postcondition: |
  - `cell_is_p2sh` = 1 iff len == 23 and bytes are a9 14 .. 87 (OP_HASH160,
    20-byte push, OP_EQUAL), else 0, for every 64-bit input.
  - `cell_p2sh_reeval` result(2) | error_kind(6) << 2:
      ss_err != 0                     -> (0, ss_err)
      ss_depth = 0                    -> (0, 18)  INVALID_STACK_OPERATION
      hash_match = 0                  -> (0, 2)   EVAL_FALSE (OP_EQUAL false)
      pushonly_ok = 0                 -> (0, 26)  SIG_PUSHONLY
      redeem_err != 0                 -> (0, redeem_err)
      redeem depth 0 / false top      -> (0, 2)   EVAL_FALSE
      otherwise                       -> (1, 0)   success
  - Error precedence is part of the postcondition: the scriptPubKey
    evaluation (and therefore the hash comparison) precedes the push-only
    check, so a hash mismatch reports EVAL_FALSE even when scriptSig is not
    push-only.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-005
scr_row_coverage: >-
  partial. Proved: (a) the 23-byte HASH160/EQUAL template predicate for every
  byte and length (so "23-byte HASH160 script" is exactly Core's
  IsPayToScriptHash, not an approximation); (b) the P2SH arm restores the
  post-scriptSig stack (stackCopy), removes exactly one element (the
  serialized redeem script, the last scriptSig stack element) and evaluates
  that subscript on the remainder; (c) the resulting stack's final truth is
  the decision; (d) the hash-equality gate and its precedence over the
  push-only check. NOT proved: the HASH160 computation itself (opaque seam —
  `hash_match` is a symbolic premise), the serialization of the redeem script
  bytes vs. the scriptSig push (`scriptSig == CScript() << pubKey2`, the
  WITNESS_MALLEATED_P2SH check, a different row SCR-012), the BIP16 activation
  rule, and sigop counting. The `GetSigOpCount`/P2SH preimage paths are out of
  scope.
patches: none
source_citations:
  - script.cpp:224-231 (CScript::IsPayToScriptHash, 23 bytes / a9 / 14 / 87)
  - interpreter.cpp:2062-2066 (P2SH flag + template, push-only check)
  - interpreter.cpp:2068-2078 (swap(stack, stackCopy); top = redeem; popstack)
  - interpreter.cpp:2080-2086 (EvalScript(redeem), empty/false top)
  - twin/runtime.inc:309-311 (twin is_p2sh)
  - twin/runtime.inc:812-841 (twin P2SH block: saved stack, redeem, truth)
  - Defs.lean:1327-1353 (p2shInner: parse, push-only, stackCopy split,
    evalScriptBytes on the redeem script)
  - Defs.lean:1402-1431 (P2SH call site and cleanstack-relevant final length)
  - contract/error_enum.md:52,62,37 (ordinals 18, 26, 2)
trust_note: >
  The C leg transcribes Core's template test and P2SH arm; the L leg is a
  reviewed transliteration of the twin `is_p2sh`/P2SH block and the Lean
  `p2shInner`. Both legs carry the same declared seams: the HASH160 transform
  (`hash_match` is a symbolic premise, never claimed) and the redeem-script
  EvalScript outcome. The twin's ParseFail -> BAD_OPCODE arm is documented as
  unreachable after a successful scriptSig evaluation (EvalScript would have
  returned BAD_OPCODE first), so the reachable push-only states are Ok and
  NotPush. No Core patch; no crypto claimed.
mutant: >
  Proposed, not executed: in the L leg, skip the `popstack` before evaluating
  the redeem script (evaluate it with the redeem element still on the stack).
  Expected Alive2 counterexample whenever the redeem evaluation's final stack
  depends on the extra element, and a SAW proof failure.
---
