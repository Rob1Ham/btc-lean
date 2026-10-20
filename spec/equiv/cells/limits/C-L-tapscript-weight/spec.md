---
# Cell limits/C-L-tapscript-weight
cell: C-L-tapscript-weight
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (two symbolic functions, both directions)
precondition: |
  - Budget function: the tapscript arm of VerifyWitnessProgram initializes
    execdata.m_validation_weight_left to
    GetSerializeSize(witness.stack) + 50 (interpreter.cpp:1991-1992).
    The cell models a witness stack of at most 4 items (four 32-bit length
    arguments) and every 32-bit item length. This arity bound is the reason
    SCR-040 is partial.
  - Checksig function: EvalChecksigTapscript's accounting prefix
    (interpreter.cpp:360-377). `w_in` is the current
    m_validation_weight_left in its 32-bit range (the real budget is derived
    from a witness stack, so |w| < 2^31; the SAW precondition states the
    bounds). `sig_nonempty` is `!sig.empty()`. `pk_class` is the
    classification of pubkey.size(): 0 = 0, 1 = 32, 2 = any other
    (upgradable) size. `discourage` is SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_
    PUBKEYTYPE. `checker_ok` is the Schnorr checker result (the same-crypto
    seam), used only for a non-empty signature against a 32-byte key.
postcondition: |
  - `cell_tapscript_budget`:
      CompactSize(n_items) + sum_i (CompactSize(len_i) + len_i) + 50
    with CompactSize sizes 1 (n < 253), 3 (<= 0xffff), 5 (<= 0xffffffff).
    The 9-byte CompactSize branch is unreachable for a serialized witness
    item and is still implemented.
  - `cell_tapscript_checksig` returns
      decision(2) | error(6) << 2 | success(1) << 8 | low32(w_after) << 9
    where decision 1 = no script error, 0 = a known script error, 2 = the
    checker rejected (its ordinal is outside the cell), and:
      sig non-empty, w_in - 50 < 0                -> (0, 49 TAPSCRIPT_VALIDATION_WEIGHT, success=1, w_in-50)
      sig non-empty, pk_class = 0                 -> (0, 52 TAPSCRIPT_EMPTY_PUBKEY, success=1, w_in-50)
      sig non-empty, pk_class = 1, checker fails  -> (2,  0, success=1, w_in-50)
      sig non-empty, pk_class = 1, checker ok     -> (1,  0, success=1, w_in-50)
      sig non-empty, pk_class = 2, discourage     -> (0, 37 DISCOURAGE_UPGRADABLE_PUBKEYTYPE, success=1, w_in-50)
      sig non-empty, pk_class = 2, no discourage  -> (1,  0, success=1, w_in-50)
      sig empty, pk_class = 0                     -> (0, 52, success=0, w_in)
      sig empty, pk_class = 1                     -> (1,  0, success=0, w_in)
      sig empty, pk_class = 2, discourage         -> (0, 37, success=0, w_in)
      sig empty, pk_class = 2, no discourage      -> (1,  0, success=0, w_in)
  - The weight test precedes the pubkey rules, so an under-budget non-empty
    signature against an empty or upgradable key reports
    TAPSCRIPT_VALIDATION_WEIGHT, exactly as Core.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-040, SCR-041, SCR-042
scr_row_coverage: |
  - SCR-040 (budget = serialized witness stack size including the
    CompactSize item count, + 50 WU): partial. The formula, the item-count
    CompactSize and the per-item CompactSize+bytes are proved for 0..4 items
    and all 32-bit item lengths; the CompactSize 1/3/5-byte branches are all
    exercised. Missing: an unbounded item count (the cell has four length
    arguments) and the 9-byte CompactSize branch (an item > 2^32-1 bytes,
    unreachable in a valid serialized witness). It must not be cited as a
    full SCR-040 green.
  - SCR-041 (decrement on non-empty sig regardless of validity; < 0 =>
    TAPSCRIPT_VALIDATION_WEIGHT): full. The decrement by 50 is proved for
    every non-empty signature and every signed weight value, the negative
    test is exact, and its precedence over the pubkey rules is proved.
    Signature validity is the `checker_ok` input, so the decrement is shown
    for both outcomes, including an invalid signature.
  - SCR-042 (non-empty sig + upgradable key still decrements): full. For
    pk_class = 2 (every size other than 0 and 32) with a non-empty signature,
    the budget is decremented before the discouragement branch, and the
    observable post-state carries w_in - 50.
patches: none
source_citations:
  - interpreter.cpp:1991-1992 (validation_weight_left = GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET)
  - script.h:60-65 (VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50; VALIDATION_WEIGHT_OFFSET = 50)
  - serialize.h:291-297 (GetSizeOfCompactSize)
  - serialize.h:898-906, 1156-1160 (vector serialization and GetSerializeSize)
  - interpreter.cpp:360-377 (EvalChecksigTapscript decrement and negative test)
  - interpreter.cpp:379-395 (empty-pubkey, 32-byte check, upgradable-key discouragement)
  - contract/error_kind.h:74,90,93 (DISCOURAGE_UPGRADABLE_PUBKEYTYPE=37, TAPSCRIPT_VALIDATION_WEIGHT=49, TAPSCRIPT_EMPTY_PUBKEY=52)
  - spec/core/Bitcoin/Interpreter/Defs.lean:757-788, 1207-1229 (evalChecksigTapscript, budget init)
  - spec/core/Bitcoin/Crypto/Taproot/Program.lean:595-642 (witnessSerSize, VALIDATION_WEIGHT_OFFSET, validationWeightInit)
  - spec/core/Bitcoin/Data/Basic.lean:73-77 (compactSizeEnc)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp/script.h/
  serialize.h at the pin. L is a reviewed transliteration of the Lean
  evalChecksigTapscript and witnessSerSize/validationWeightInit definitions.
  The Schnorr checker is the declared same-crypto seam: its result is an
  input and its error ordinal is not modelled (decision=2 marks a checker
  rejection). No hash, signature or script-execution claim is made. Alive2
  compares the C and L IR for both functions; SAW verifies both against the
  independent Cryptol predicates under the stated bounds. No Core patch is
  used.
mutant: >
  Proposed, not executed: move the weight decrement inside the
  `pk.size() == 32` branch, so an upgradable key escapes the charge.
  Expected: Alive2 counterexample at pk_class = 2 with a non-empty signature
  (C = w-50, L = w); SAW failure. A second proposed mutant changes the
  negative test to `<= 0` and should be killed at w_in = 50.
---
