---
# Cell exec-verify/C-L-w65-scr008-cleanstack-arms
cell: C-L-w65-scr008-cleanstack-arms
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5e42f8a337e41a7308158b0de078afafd9
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green on the declared domain; the F-DIV-W32-01 class is excluded from the domain and recorded red (not green) in findings/wave65/02-scr008-full-cell
precondition: |
  - Cell region: every computation between the successful scriptPubKey
    `EvalScript` and `set_success` that determines the CLEANSTACK-relevant
    final stack length, plus the terminal CLEANSTACK and WITNESS_UNEXPECTED
    checks.  Core sites: bare witness arm 2045-2058 (`stack.resize(1)` at
    2057), P2SH arm 2062-2105 (`stack.resize(1)` at 2102), CLEANSTACK
    2110-2118, WITNESS tail 2120-2127.
  - The scriptSig and scriptPubKey `EvalScript` calls already succeeded and
    left a non-empty, truthy stack.  The EVAL_FALSE checks (2037-2040) are
    `exec-verify/C-L-verifyscript-tail`.
  - `flags` is in the contract domain (SCR-009, `C-L-flags-domain`): only
    `witness`, `p2sh`, `cleanstack` are read, as bits.
  - Declared shape inputs: `spk_wit` = `scriptPubKey.IsWitnessProgram(...)`,
    `spk_p2sh` = `scriptPubKey.IsPayToScriptHash()`, `redeem_wit` =
    `redeemScript.IsWitnessProgram(...)`.  The script-shape predicates are
    inputs (the 23-byte P2SH shape is `C-L-p2sh-handoff`).
  - `ss_push_ok` = `scriptSig == CScript() << redeemScript` (2092), an input;
    the comparison itself is computed in `C-L-verifyscript-tail`
    (`cell_single_push_eq`, redeemScript <= 2 bytes, single-byte push).
  - `st_n` = post-scriptPubKey depth (0..3); `inner_len` = depth left by the
    P2SH subscript `EvalScript` (0..3); `sig_n` = `scriptSig.size()` (0..3);
    `wit_n` = witness item count (0..3, `IsNull()` is `== 0`).
  - Both `VerifyWitnessProgram` calls are abstracted to success (failure
    propagation: SCR-017, `C-L-failure-propagation`).  The P2SH push-only
    check is a precondition (SCR-006, `C-L-pushonly`).
  - DECLARED DOMAIN.  The equality is claimed only on inputs satisfying
    `ev_scr008_in_domain()` (src/common.h), called by both legs:
      (a) not (`spk_wit` ∧ `spk_p2sh`) — a scriptPubKey cannot be both a
          witness program and P2SH (disjoint leading opcodes/shape);
      (b) not (`p2sh` ∧ `spk_p2sh` ∧ `witness` ∧ `redeem_wit` ∧
          `cleanstack` ∧ `ss_push_ok`) — the P2SH-wrapped witness arm under
          CLEANSTACK with the 2092 guard passed, which is F-DIV-W32-01.
          This cell does NOT cover that set.  (With `ss_push_ok = 0` both
          models return 42 before the CLEANSTACK check, so that sub-case
          *is* in the domain and is covered.)
    The excluded class is exercised red in
    `findings/wave65/02-scr008-full-cell/`.
postcondition: |
  `cell_scr008_arms` returns the packed pair `result(2) | error(6) << 2`:
  - WITNESS on, scriptPubKey is a native witness program,
    scriptSig non-empty                            -> (0, 41) WITNESS_MALLEATED
  - P2SH on, scriptPubKey is P2SH, WITNESS on, redeemScript is a witness
    program, scriptSig is not its single push      -> (0, 42) WITNESS_MALLEATED_P2SH
  - CLEANSTACK on and the final depth != 1         -> (0, 30) CLEANSTACK
  - WITNESS on, no witness program was consumed, witness non-null
                                                   -> (0, 43) WITNESS_UNEXPECTED
  - otherwise                                      -> (1, 0)  pass
  with the final depth
    * `resize(1)` for a consumed witness program (bare and — inside the
      declared domain — the wrapped arm with CLEANSTACK off),
    * `inner_len` for the non-witness P2SH subscript,
    * `st_n` for a plain script,
  and error precedence exactly Core's: 41, then 42, then 30, then 43.
  On the complement of the declared domain both legs return the sentinel
  0xffffffffffffffff (harness).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-008
scr_row_coverage: |
  partial — and the maximum behaviour-preserving coverage available at the
  pinned model.

  Covered, both tools green, over the declared domain:
  - plain script (no witness program, no P2SH): `final depth = st_n` for
    every depth 0..3, CLEANSTACK iff `cleanstack ∧ st_n != 1`;
  - native (bare) witness program: `resize(1)` at 2057, so CLEANSTACK cannot
    fire once the witness program is consumed; also the WITNESS_MALLEATED
    (41) and WITNESS_UNEXPECTED (43) interactions;
  - plain P2SH (redeem script is not a witness program): `final depth =
    inner_len` for every 0..3, CLEANSTACK iff `cleanstack ∧ inner_len != 1`;
  - P2SH-wrapped witness program with `cleanstack = false`: the 42 guard and
    the 43 tail agree; the cleanstack length is not read.

  NOT covered (excluded from the domain, and *divergent*, not merely
  unproved): P2SH-wrapped witness program with `cleanstack = true` and the
  scriptSig equal to the single push of the redeem script.
  Core resizes to one element at 2102, so the 2115 test cannot fire.  The
  pinned Lean `verifyScriptFull` computes
      finalLen := if flags.witness ∧ (isWitnessProgram spk).isSome then 1
                  else <redeem-script eval length>
  where `spk` is the P2SH scriptPubKey, so the arm keeps the inner length
  (2 for a v0 witness program) and the model rejects a valid spend with
  CLEANSTACK.  Exact witness, real Core and real Lean runs, the Alive2
  counterexample and the one-line fix that makes the full three-arm cell
  green: `findings/wave65/02-scr008-full-cell/report.md`.  Until the model
  is fixed (or SCR-008 is re-scoped to the flag/policy faces), SCR-008 is
  not closable.
patches: none
source_citations:
  - interpreter.cpp:2045-2058 (bare witness program; 2048-2050 WITNESS_MALLEATED; 2057 resize(1))
  - interpreter.cpp:2062-2105 (P2SH arm; 2092-2095 WITNESS_MALLEATED_P2SH; 2102 resize(1))
  - interpreter.cpp:2110-2118 (CLEANSTACK check; asserts 2113-2114)
  - interpreter.cpp:2120-2127 (WITNESS tail; WITNESS_UNEXPECTED)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1327-1355 (p2shInner)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1363-1446 (verifyScriptFull; finalLen 1412-1430, cleanstack 1431, bare-face cleanstack 1443)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1398-1402 (afterBare resize)
  - contract/error_kind.h (ordinals 30, 41, 42, 43)
trust_note: >
  C is a line-cited source-excerpt slice of Core at the pin; the three
  sub-calls (the P2SH subscript EvalScript, both VerifyWitnessProgram calls)
  are declared outcome inputs, so the cell proves the length selection and
  error precedence for every outcome they can produce — not their own
  behaviour.  L is a reviewed transliteration of `verifyScriptFull`/
  `p2shInner`, NOT generated by twin/ops_ir.py (the twin has no VerifyScript
  handler).  The L leg reproduces the pinned model's `finalLen` literally,
  including its dependence on `isWitnessProgram spk`; the cell does not
  "fix" the model in the transliteration (the older
  `C-L-verifyscript-tail`/`C-L-w32-cleanstack` cells did, which is why they
  cannot speak for the pinned model on this row).  The cost is a declared
  input domain that excludes the divergent class; that exclusion is the
  residual, and it is demonstrated red rather than hidden.  No crypto, hash,
  signature, or script execution is claimed.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: move the 42 guard (WITNESS_MALLEATED_P2SH) after
  the CLEANSTACK check in the L leg.  Expected Alive2 counterexample inside
  the declared domain at `p2sh = 1, spk_p2sh = 1, witness = 1,
  redeem_wit = 1, ss_push_ok = 0, cleanstack = 1, inner_len != 1` (C returns
  42, the mutant returns 30), and a SAW failure on `cell_scr008_arms`.
  A second, model-shape mutant is deliberately *not* proposed: flipping
  `bare_wit ? 1 : inner_len` to `inner_len` in the P2SH branch is invisible
  on this domain, because `spk_wit = 0` whenever `spk_p2sh = 1` — that is
  precisely the F-DIV-W32-01 point, and it is exercised by the full-domain
  probe in findings/wave65/02-scr008-full-cell/ instead.
---

# exec-verify/C-L-w65-scr008-cleanstack-arms

The CLEANSTACK-relevant final length of `VerifyScript` across the row's three
paths — plain script, native witness program, P2SH-wrapped witness program —
with the terminal CLEANSTACK and WITNESS_UNEXPECTED checks and Core's error
precedence.

This cell exists because SCR-008 was demoted after F-DIV-W32-01: the older
cells proved the flag/policy face and *assumed* Core's `resize(1)` for the
wrapped arm in the L leg. This cell instead transliterates the pinned Lean
`finalLen` literally and declares, as its domain, exactly the inputs on which
that model is behaviour-preserving. Everything outside that domain is
reproduced red in `findings/wave65/02-scr008-full-cell/`, with the counter-
example and the fix.

## The three paths

```c
// 2045-2058 native witness program
if (flags & SCRIPT_VERIFY_WITNESS) {
  if (scriptPubKey.IsWitnessProgram(...)) {
    hadWitness = true;
    if (scriptSig.size() != 0) return WITNESS_MALLEATED;
    if (!VerifyWitnessProgram(...)) return false;
    stack.resize(1);                       // 2057
  }
}
// 2062-2105 P2SH
if ((flags & SCRIPT_VERIFY_P2SH) && scriptPubKey.IsPayToScriptHash()) {
  ... EvalScript(subscript) ...
  if (flags & SCRIPT_VERIFY_WITNESS) {
    if (pubKey2.IsWitnessProgram(...)) {
      hadWitness = true;
      if (scriptSig != CScript() << redeem) return WITNESS_MALLEATED_P2SH;
      if (!VerifyWitnessProgram(..., /*is_p2sh=*/true)) return false;
      stack.resize(1);                     // 2102
    }
  }
}
// 2110-2118
if (flags & SCRIPT_VERIFY_CLEANSTACK) {
  assert(P2SH); assert(WITNESS);
  if (stack.size() != 1) return CLEANSTACK;
}
```

Lean carries a *length* instead of the stack, and the pinned model computes it
as `if flags.witness ∧ (isWitnessProgram spk).isSome then 1 else <redeem eval
length>` inside the P2SH branch. `spk` is the P2SH scriptPubKey, so the `1`
only ever fires for the bare arm. That is the whole of F-DIV-W32-01.

## What the cell proves

Over the declared domain (see `precondition`), C and L agree for every value
of all eleven inputs, and both match the shared Cryptol table. The four
covered faces are enumerable and exhaustive within their bounds:

| path | final depth | CLEANSTACK fires |
|---|---|---|
| plain script | `st_n` (0..3) | `cleanstack ∧ st_n != 1` |
| native witness | 1 | never |
| plain P2SH | `inner_len` (0..3) | `cleanstack ∧ inner_len != 1` |
| P2SH-wrapped witness, `cleanstack = false` | not read | never |
| P2SH-wrapped witness, `cleanstack = true` | **excluded** | **divergent** |

## What is not proved

- The excluded class above (F-DIV-W32-01).
- The `EvalScript` calls, the subscript evaluation, `VerifyWitnessProgram`.
- The general single-push encoding for redeemScript >= 76 bytes.
- The 8/16/32/64-bit bounds are cell-harness bounds on *inputs*; the region has
  no data-dependent loop, so no predicate is approximated.

## Exact commands

```sh
bash spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/saw/certificate.sha256
```

Observed: Alive2 `1 correct transformations, 0 incorrect, 0 Alive2 errors`
(`STATUS=alive2-green`); SAW two `Proof succeeded!` against `cell.cry`
(`STATUS=saw-green`).
