---
# Cell exec-verify/C-L-verifyscript-tail
cell: C-L-verifyscript-tail
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic VerifyScript tail; sub-calls abstracted to their outcomes)
precondition: |
  - The tail of `VerifyScript` (interpreter.cpp:2037-2127): everything after
    the *scriptPubKey* `EvalScript` call.  The scriptSig and scriptPubKey
    evaluations, and the P2SH subscript evaluation, are not modelled; their
    results enter as described below.
  - `flags` is in the contract domain (contract/tape.md §5, proved by
    `cells/exec-verify/C-L-flags-domain`); only three bits are read, passed
    as booleans: `witness` (0x800), `p2sh` (0x1), `cleanstack` (0x100).
  - Post-scriptPubKey stack: depth `st_n` in 0..3; the top element is 0 or 1
    bytes (`top_len`, `top_b`), which makes `CastToBool` exact
    (interpreter.cpp:46-59: empty / 0x00 / 0x80 are false).
  - `spk_wit` = `scriptPubKey.IsWitnessProgram(...)` and `spk_p2sh` =
    `scriptPubKey.IsPayToScriptHash()` are declared shape inputs; they are
    the script-shape predicates, not script execution.  (The 23-byte P2SH
    shape itself is proved in `cells/exec-verify/C-L-p2sh-handoff`.)
  - `sig_n` = `scriptSig.size()` (0..3); `sig_push_ok` =
    `scriptSig == CScript() << redeemScript`, computed by
    `cell_single_push_eq` in this cell for redeemScript lengths 0..2 and the
    single-byte push encoding.
  - `wit_n` = witness stack item count (0 == `CScriptWitness::IsNull()`).
  - `p2sh_wit_prog` = `redeemScript.IsWitnessProgram(...)`.
  - `p2sh_len` = depth of the stack after the *non-witness* P2SH subscript
    `EvalScript` returns ok (0..3).  The subscript evaluation and its
    EVAL_FALSE checks (2083-2086) are abstracted to this length; the handoff
    of the scriptSig stack into that call is proved separately in
    `cells/exec-verify/C-L-p2sh-handoff` (SCR-007).
  - Both `VerifyWitnessProgram` calls (2052-2054, 2097-2099) are abstracted
    to success.  Their failure propagation is SCR-017, covered by
    `cells/exec-verify/C-L-failure-propagation`.
  - The P2SH push-only check at 2065-2066 is a precondition here (push-only
    is assumed); it is covered by `cells/exec-verify/C-L-pushonly`.
  - The P2SH-witness arm's final depth is Core's `stack.resize(1)` (2102).
    Lean recomputes it as the subscript eval length; on the reachable domain
    the 42 guard forces scriptSig to be exactly `push(redeemScript)`, so the
    recomputation is also 1 (see notes.md).
postcondition: |
  `cell_vs_tail` returns the packed pair `result(2) | error(6) << 2`:
  - depth 0                                     -> (0, 2)  EVAL_FALSE
  - top CastToBool false (0x00 / 0x80 / empty)  -> (0, 2)  EVAL_FALSE
  - WITNESS on, scriptPubKey is a witness
    program, scriptSig non-empty                -> (0, 41) WITNESS_MALLEATED
  - P2SH on, scriptPubKey is P2SH, WITNESS on,
    redeemScript is a witness program,
    scriptSig is not its single push            -> (0, 42) WITNESS_MALLEATED_P2SH
  - CLEANSTACK on and the final depth != 1      -> (0, 30) CLEANSTACK
  - WITNESS on, no witness was consumed
    (hadWitness false), witness non-null        -> (0, 43) WITNESS_UNEXPECTED
  - otherwise                                   -> (1, 0)  pass
  where the final depth is `resize(1)` after a consumed witness program,
  `p2sh_len` for the non-witness P2SH arm, and `st_n` otherwise; error
  precedence is exactly Core's order (41 before 42/30/43; 42 before 30/43;
  30 before 43).  C and L agree for every input (Alive2); both match the
  shared Cryptol table (SAW).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-002, SCR-004, SCR-008, SCR-011, SCR-012, SCR-013
scr_row_coverage: |
  per row, with the bounds above:
  - SCR-002 full — "after scriptPubKey eval, stack non-empty and top
    CastToBool-true" (interpreter.cpp:2037-2040): proved for every post-eval
    stack in the bounded domain (depth 0..3, top 0/1 bytes) and every mask.
  - SCR-004 partial — the two arms cited by the row:
      WITNESS off, empty scriptPubKey, scriptSig leaves one truthy element
        -> pass (modelled: spk_wit = spk_p2sh = 0, st_n = 1, top truthy);
      WITNESS on, witness non-null, empty scriptPubKey (not a witness
        program) -> WITNESS_UNEXPECTED (modelled: spk_wit = 0, wit_n > 0);
    NOT covered: the scriptSig evaluation that *produces* the single truthy
    element (a push executed by EvalScript — E5 dispatch residual), and the
    row's explicitly unproved CLEANSTACK-on one-element arm.
  - SCR-008 partial — "exactly 1 element after all evaluation" (flag; pol.;
    interpreter.cpp:2110-2118): the flag/policy check is proved for every
    final depth in Core's order, but the witness-implicit face is blocked by
    the model divergence F-DIV-W32-01: for a valid P2SH-wrapped v0 witness
    spend Core resizes the stack to one element at :2102 while the pinned Lean
    `verifyScriptFull` reuses the redeem-script length and rejects with
    CLEANSTACK.  See findings/wave64/41-div-w32-p2sh-cleanstack.  What is
    assumed in the green flag/policy face is only the depth handed in by the
    abstracted evaluations.
  - SCR-011 full — bare witness program requires scriptSig == CScript()
    (interpreter.cpp:2045-2051): proved for every scriptSig size.
  - SCR-012 partial — "scriptSig == single push of redeemScript"
    (interpreter.cpp:2092-2096): the comparison is computed
    (`cell_single_push_eq`) and used in the guard, but only for redeemScript
    lengths 0..2 and the single-byte push encoding; PUSHDATA1/2/4 encodings
    (redeemScript >= 76 bytes) are not modelled.
  - SCR-013 full — non-null witness without a witness program
    (interpreter.cpp:2120-2127): proved for every witness item count, with
    hadWitness derived from both witness arms.
patches: none
source_citations:
  - interpreter.cpp:2037-2040 (stack.empty / CastToBool -> EVAL_FALSE)
  - interpreter.cpp:2045-2058 (bare witness program; WITNESS_MALLEATED; resize(1))
  - interpreter.cpp:2062-2105 (P2SH arm; 2092-2095 WITNESS_MALLEATED_P2SH; resize(1))
  - interpreter.cpp:2110-2118 (CLEANSTACK check and its two asserts)
  - interpreter.cpp:2120-2127 (WITNESS tail; WITNESS_UNEXPECTED)
  - interpreter.cpp:46-59 (CastToBool)
  - script.h:408-423,484-489 (CScript::operator<< vector: canonical push encoding)
  - prevector.h:429 (element-wise ==)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1328-1355 (p2shInner), 1363-1455 (verifyScriptFull)
  - contract/error_kind.h:27,65,80,81,82 (ordinals 2, 30, 41, 42, 43)
trust_note: >
  This is a bounded tail cell, not a whole-VerifyScript proof.  C is a
  line-cited source-excerpt slice; the three sub-calls
  (scriptSig/scriptPubKey EvalScript, the P2SH subscript EvalScript,
  VerifyWitnessProgram) are declared outcome inputs, so the cell proves the
  tail's dispatch and error precedence for every outcome they can produce —
  not their own behaviour.  L is a reviewed transliteration of
  `verifyScriptFull`/`p2shInner`, NOT generated by twin/ops_ir.py (the twin
  has no VerifyScript handler); the one place where it follows Core rather
  than Lean's recomputation is the P2SH-witness final depth, disclosed above
  and in notes.md.  Script-shape predicates (`IsWitnessProgram`,
  `IsPayToScriptHash`) are declared inputs except for the single-push
  comparison, which is computed in-cell under its length bound.  No crypto,
  hash, signature, or script execution is claimed.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: in the L leg drop the `!had` conjunct of the SCR-013
  tail (always fail on a non-null witness).  Expected Alive2 counterexample at
  witness=1, spk_wit=1, sig_n=0, wit_n=1 (C returns pass, L returns 43);
  SAW failure on `cell_vs_tail`.  A second mutant: check CLEANSTACK before the
  P2SH arm; expected counterexample where both 42 and 30 are reachable and
  precedence differs.
---

# exec-verify/C-L-verifyscript-tail

The post-`EvalScript` tail of `VerifyScript`: truth check, bare witness
malleability, P2SH witness malleability, cleanstack, unexpected witness, and
their error precedence.

## The region

```c
// interpreter.cpp:2037-2040
if (stack.empty()) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
if (CastToBool(stack.back()) == false) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);

// 2045-2058 bare witness program
if (flags & SCRIPT_VERIFY_WITNESS) {
  if (scriptPubKey.IsWitnessProgram(witnessversion, witnessprogram)) {
    hadWitness = true;
    if (scriptSig.size() != 0) return set_error(serror, SCRIPT_ERR_WITNESS_MALLEATED);
    if (!VerifyWitnessProgram(...)) return false;
    stack.resize(1);
  }
}
// 2062-2105 P2SH
if ((flags & SCRIPT_VERIFY_P2SH) && scriptPubKey.IsPayToScriptHash()) {
  if (!scriptSig.IsPushOnly()) return set_error(serror, SCRIPT_ERR_SIG_PUSHONLY);
  swap(stack, stackCopy); popstack(stack);          // redeemScript
  if (!EvalScript(stack, pubKey2, ...)) return false;
  if (stack.empty()) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
  if (!CastToBool(stack.back())) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
  if (flags & SCRIPT_VERIFY_WITNESS) {
    if (pubKey2.IsWitnessProgram(witnessversion, witnessprogram)) {
      hadWitness = true;
      if (scriptSig != CScript() << std::vector(pubKey2...))
        return set_error(serror, SCRIPT_ERR_WITNESS_MALLEATED_P2SH);
      if (!VerifyWitnessProgram(...)) return false;
      stack.resize(1);
    }
  }
}
// 2110-2118 CLEANSTACK
if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
  assert(P2SH); assert(WITNESS);
  if (stack.size() != 1) return set_error(serror, SCRIPT_ERR_CLEANSTACK);
}
// 2120-2127 WITNESS tail
if (flags & SCRIPT_VERIFY_WITNESS) {
  assert(P2SH);
  if (!hadWitness && !witness->IsNull())
    return set_error(serror, SCRIPT_ERR_WITNESS_UNEXPECTED);
}
return set_success(serror);
```

## The two invariants this cell is about

- `hadWitness` is set by *either* witness arm (bare and P2SH-wrapped) and by
  nothing else.  SCR-013 is exactly `!hadWitness && !witness->IsNull()`.
- the final depth that CLEANSTACK sees is not the post-`scriptPubKey` depth:
  it is `resize(1)` if a witness program was consumed, the subscript result
  for plain P2SH, and `st_n` otherwise.  SCR-008 is exactly the `!= 1` test
  on that depth.

The bounds are the ones in the front matter: post-eval depth <= 3, top
element <= 1 byte, scriptSig size <= 3, witness items <= 3, redeemScript
length <= 2 for the single-push comparison.  All are cell-harness bounds on
*inputs*, not weakened predicates: the tail has no data-dependent loop.

## What is not proved

- The `scriptSig`/`scriptPubKey` `EvalScript` calls themselves (E5 residual:
  GetScriptOp, dispatch, heap vectors).  Their post-state enters as inputs.
- The P2SH subscript evaluation and its EVAL_FALSE checks.
- `VerifyWitnessProgram` (any version).  Both calls are success here; failure
  propagation is the SCR-017 cell.
- The P2SH push-only check (SCR-006, `C-L-pushonly`) and the stack handoff
  (SCR-007, `C-L-p2sh-handoff`), both separate cells.
- The general single-push encoding for redeemScript >= 76 bytes (PUSHDATA1).

## Exact commands

```sh
bash spec/equiv/cells/exec-verify/C-L-verifyscript-tail/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-verifyscript-tail/saw/run.sh
# from the repository root:
sha256sum -c spec/equiv/cells/exec-verify/C-L-verifyscript-tail/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-verifyscript-tail/saw/certificate.sha256
```

## Results (raw tails)

Alive2: two comparisons (`cell_single_push_eq`, `cell_vs_tail`), each
`1 correct transformations`, `0 incorrect`, `0 Alive2 errors`,
`STATUS=alive2-green`.

SAW: four `Proof succeeded!` (two functions × C/L) against `saw/cell.cry`,
`STATUS=saw-green`.
