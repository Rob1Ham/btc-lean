---
# Cell tapscript/C-L-w32-pubkey-triage
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
r_leg: "not attempted: no tapscript triage cell on the pinned rbitcoin lane; IR not Alive2-ingestable (F-TOOL-001)"
cell: C-L-w32-pubkey-triage
family: tapscript
tool_status: both-green (Alive2 symbolic over the bounded domain; SAW concrete scenarios)
precondition: |
  - One call to EvalChecksigTapscript (interpreter.cpp:357-400), as reached
    from CHECKSIG/CHECKSIGVERIFY/CHECKSIGADD under SigVersion::TAPSCRIPT.
  - The signature element is symbolic in length 0..255; only emptiness
    matters to this helper. The pubkey element is symbolic in length
    0..255; only the classes 0, 32 and "other" matter.
  - DISCOURAGE_UPGRADABLE_PUBKEYTYPE is symbolic; the other policy flags are
    irrelevant to this helper.
  - The incoming validation weight is symbolic in [-100, 923]
    (seed 0..1023 minus 100), so both the `>= 50` and `< 50` branches of
    the decrement are reachable.
  - The Schnorr verdict is the unconstrained return of the shared external
    btc_equiv_check_schnorr; no BIP340/secp256k1 property is assumed.
postcondition: |
  Triage observable (src/tap_common.h, `tp_pack_triage`):
    bit 0 eval_ok, bits 1..6 error ordinal, bit 7 success,
    bits 8..23 validation weight after the call (int16),
    bit 24 checker call site reached.
  - sig empty, pubkey empty: (0, EMPTY_PUBKEY=52, success 0, weight unchanged,
    called 0).
  - sig non-empty, pubkey empty: weight is decremented by 50 first; if it
    becomes negative the result is (0, TAPSCRIPT_VALIDATION_WEIGHT=49,
    weight decremented, called 0); otherwise (0, TAPSCRIPT_EMPTY_PUBKEY=52,
    weight decremented, called 0).
  - pubkey length 32:
      * sig empty: (1, 0, success 0, weight unchanged, called 0);
      * sig non-empty: called 1, weight decremented; checker false ->
        (0, SCHNORR_SIG=47); checker true -> (1, 0, success 1).
  - any other non-empty pubkey length: weight decremented only for a
    non-empty sig; with DISCOURAGE_UPGRADABLE_PUBKEYTYPE ->
    (0, DISCOURAGE_UPGRADABLE_PUBKEYTYPE=37), otherwise
    (1, 0, success = (sig non-empty), called 0).
  - `cell_triage_continue` additionally runs the CHECKSIGADD push
    (interpreter.cpp:1112): on success it returns the standard step
    observable with top = canonical encoding of `num + (success?1:0)`.
    For the empty-signature/32-byte-key case that is exactly `num`, and the
    step continues (result=1, depth=1).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-158, SCR-159, SCR-160
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "script/interpreter.cpp:357-400 (EvalChecksigTapscript)"
  - "script/interpreter.cpp:367 (success = !sig.empty())"
  - "script/interpreter.cpp:369-375 (validation-weight decrement and TAPSCRIPT_VALIDATION_WEIGHT)"
  - "script/interpreter.cpp:377-378 (TAPSCRIPT_EMPTY_PUBKEY)"
  - "script/interpreter.cpp:379-382 (32-byte x-only -> CheckSchnorrSignature only when success)"
  - "script/interpreter.cpp:383-392 (upgradable pubkey type)"
  - "script/interpreter.cpp:1094-1113 (CHECKSIGADD continuation at 1112)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:757-780 (evalChecksigTapscript)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:261-267 (checkSchnorrWithContext, typed seam = none)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:91 (VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1048-1059 (CHECKSIGADD arm)"
  - "contract/error_kind.h:37,45,46,47,49,52 (ordinals)"
trust_note: >
  SAME-CRYPTO CONDITION: both legs call the one external symbol
  btc_equiv_check_schnorr with the same (sig, pubkey, sigversion) encoding;
  Alive2's same-symbol model and the SAW shared stub pin the verdict to
  0 or 1. Nothing here proves BIP340, secp256k1, sighash or SHA256
  agreement. The claim is conditional on the two checkers agreeing, as in
  docs/DECISION-lax-ecdsa.md.

  C is a line-cited source slice of interpreter.cpp at the pin. L is a
  REVIEWED TRANSLITERATION of the Lean equations at lean_model_rev (the
  repo's generated twin/ops_ir.py has no tapscript handler). `called` is
  cell-harness instrumentation of the call site, not an engine value: it is
  set immediately before the shared checker symbol is invoked, so
  `called=0` on the empty-signature path is the cell-level form of
  "no Schnorr verification". The error-path weight and the `called` bit are
  threaded explicitly because the Lean `Except` value carries no state;
  the Core side mutates `execdata.m_validation_weight_left` in place.
  On error the success bit is fixed to 0 in both legs (Core's partially
  written `success` is not part of the contract observable and Lean drops
  it).

  SAW is a concrete-scenario lane; Alive2 is the symbolic bounded-domain
  equivalence evidence. Neither proves the caller's full EvalScript loop,
  witness/annex handling, the validation-weight *initialisation*
  (`GetSerializeSize(witness.stack) + 50`), SCRIPT_SIZE, or OP_SUCCESSx.
  The continuation entry fixes the num operand as a one-byte value; full
  ScriptNum parsing is the sibling SCR-157 cell.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "in C: decrement the weight only after the pubkey triage, or treat the empty signature as success; in L: return success=true for an empty signature; expect Alive2/SAW to fail"
mutant_site: "src/c_tap.cpp core_eval_checksig_tapscript / src/l_tap.cpp lean_eval_checksig_tapscript"
---

# Cell `tapscript/C-L-w32-pubkey-triage`

## Row coverage

| SCR | Branches exercised | Status |
|---|---|---|
| SCR-158 (`0 => fail; 32 => schnorr; else upgradable`) | pubkey length 0, 32 and every other length 1..255; both signature-emptiness states; both DISCOURAGE_UPGRADABLE_PUBKEYTYPE states; checker 0/1; weight above/below the decrement threshold | full |
| SCR-159 (`TAPSCRIPT_EMPTY_PUBKEY` after the weight decrement) | empty pubkey with empty and non-empty sig; weight `>= 50`, exactly `50`, `< 50` (weight error precedes the empty-pubkey error); weight unchanged when the sig is empty | full |
| SCR-160 (empty tapscript sig vs 32-byte x-only key) | empty sig + 32-byte key: `success=0`, `called=0`, weight unchanged, `eval_ok=1`; `cell_triage_continue` then pushes the unchanged num and continues; non-empty sig on the same key calls the checker | full |

The Alive2 entry takes sig length, pubkey length, both policy bits and the
weight seed symbolically; no branch is exercised only by a closed witness.
SAW's concrete scenarios are corroboration against the independent oracle.

## Why the observable is not just `(result, error_kind)`

SCR-159 and SCR-160 are about *ordering and non-actions* (decrement before
the empty-pubkey error; no Schnorr call and no weight charge for an empty
signature). The contract observable `(result, error_kind)` cannot express
those. This cell therefore exposes a reviewed helper-level observable that
includes the post-call weight and the checker call-site bit. The standard
step observable is used by `cell_triage_continue` for the continuation
half of SCR-160. Both are computed identically in both legs and are packed
by cell harness, not by engine code.

## Reproduce

```sh
cd spec/equiv/cells/tapscript/C-L-w32-pubkey-triage
./alive2/run.sh
./saw/run.sh
cd /tmp/opencode/wave32/28-tapscript-156-162
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-pubkey-triage/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-w32-pubkey-triage/saw/certificate.sha256
```
