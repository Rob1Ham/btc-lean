import Bitcoin.Script.Tapscript.Delta
import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Seam.Entry

/-!
# B14 — BIP342 coverage audit: decisive kill-vectors for the COVERED-WEAK clauses

2026-10-16. X04's `Test.Script.Tapscript.Delta`
pins the happy paths of the BIP342 deltas; the DB rows they back (TPR-055..079,
SCR-121/159/160/168) all carry `test_vector_ids: []` — no corpus vector would
fail if a clause were mutated. This module lands the missing decisive pins,
each cross-checked against a python3 reference (mirrors interpreter.cpp
@cce32b168) and quoted against BIP342 (bip-0342.mediawiki @ bips 927b6de,
BSD-3-Clause):

* S1  success-then-truncated-push  → OK        (BIP342 §Spec step 2: "even if
  later bytes … would fail to decode")
* S2  CHECKMULTISIG unexecuted     → OK        ("ignored when found in
  unexecuted branch")
* S3  CHECKSIGADD arity < 3        → underflow ("fewer than 3 elements … MUST
  fail")
* S4  empty pubkey                 → fail       ("public key size is zero …
  MUST fail")
* S5  unknown pubkey type          → success / false-by-empty-sig ("no actual
  signature verification … considered to be successful")
* S6  CSA empty sig pushes `n`     (not `n + 1`)
* S7  budget −50 per sigop, exact-zero ok, below-zero fail, unknown-pk sigops
  counted ("If that brings the budget below zero, the script fails")
* S8  initial-stack element > 520  → pushSize (no SUCCESSx around)
* S9  65-byte sig with trailing SIGHASH_DEFAULT → invalid ("sig[64] ≠ 0x00")

All pins are compiler-reduced equalities; axiom footprints pinned at file end.
-/

namespace BitcoinProofs.Bip.B14

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData stubChecker)
open Bitcoin.Crypto.Seam.Entry

set_option maxRecDepth 40000

/-- The all-accepting checker (X04's `ckGood`). -/
def ckGood : ScriptChecker := ⟨stubChecker, default⟩

/-- 64-byte nonempty signature (stub verdict `true`). -/
def sig64 : ByteArray := ByteArray.mk (Array.replicate 64 (0xab : UInt8))

/-- 65-byte signature with trailing SIGHASH_DEFAULT (0x00) — invalid. -/
def sig65Default : ByteArray :=
  ByteArray.mk ((Array.replicate 64 (0xab : UInt8)).push (0x00 : UInt8))

/-- 65-byte signature with trailing explicit hashtype 0x01 — valid shape. -/
def sig65All : ByteArray :=
  ByteArray.mk ((Array.replicate 64 (0xab : UInt8)).push (0x01 : UInt8))

/-- 32-byte "pubkey" shape (stub lane; EC math not engaged). -/
def pk32 : ByteArray := ByteArray.mk (Array.replicate 32 (0x11 : UInt8))

/-- 33-byte pubkey — the "unknown public key type" (≠ 0, ≠ 32). -/
def pk33 : ByteArray := ByteArray.mk (Array.replicate 33 (0x11 : UInt8))

/-! ## S1 — OP_SUCCESSx precedes push-decode failure (C2/C3 ordering) -/

/-- Script = OP_SUCCESS80 (0x50) then a truncated OP_PUSHDATA1 (0x4c with no
length byte): the scan hits 0x50 FIRST, so validation succeeds even though
decoding the later push would fail (ref342.py S1; BIP342 step 2.1).
Mutation caught: any re-ordering that decodes before scanning ⇒ FAIL:BAD_OPCODE. -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x50:UInt8), (0x4c:UInt8)])
    default default ckGood SigVersion.tapscript = VerifyOutcome.ok := by native_decide

/-! ## S2 — CHECKMULTISIG ignored in unexecuted branch (C6) -/

/-- Script = `0 NOTIF 1 ELSE 0xae ENDIF`: the ELSE arm (OP_CHECKMULTISIG,
0xae) is never executed, so the disabled-opcode failure must NOT fire and
the final stack is exactly [0x01] (ref342.py S2). Mutation caught: executing
unexecuted 0xae ⇒ FAIL:TAPSCRIPT_CHECKMULTISIG. -/
example : executeWitnessScript 100 [] 0
    (ByteArray.mk #[(0x00:UInt8), (0x64:UInt8), (0x51:UInt8), (0x67:UInt8),
                    (0xae:UInt8), (0x68:UInt8)])
    default default ckGood SigVersion.tapscript = VerifyOutcome.ok := by native_decide

/-! ## S3 — CHECKSIGADD arity: fewer than 3 elements fails (C8) -/

/-- Empty witness, script = OP_CHECKSIGADD: underflow (BIP342 signature-opcode
rules, second bullet; ref342.py S3). -/
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0xba:UInt8)])
    default default ckGood SigVersion.tapscript
    = VerifyOutcome.fail ExecError.stackUnderflow := by native_decide

/-! ## S4 — empty pubkey fails unconditionally (C10, SCR-159) -/

/-- CHECKSIG with pk = ∅, sig nonempty: TAPSCRIPT_EMPTY_PUBKEY even though the
budget had room and the sig "would verify" (ref342.py S4). Mutation caught:
treating ∅-pk as unknown-key-type success ⇒ OK. -/
example : executeWitnessScript 100 [sig64, ByteArray.empty] 0
    (ByteArray.mk #[(0xac:UInt8)])
    default default ckGood SigVersion.tapscript
    = VerifyOutcome.fail ExecError.tapscriptEmptyPubkey := by native_decide

/-! ## S5 — unknown pubkey type: no verification, success semantics (C12, SCR-160) -/

/-- Unknown key type (33 bytes) + nonempty sig: validation "considered to be
successful" — script passes (ref342.py S5a). Mutation caught: rejecting
non-32-byte keys ⇒ FAIL. -/
example : executeWitnessScript 100 [sig64, pk33] 0 (ByteArray.mk #[(0xac:UInt8)])
    default default ckGood SigVersion.tapscript = VerifyOutcome.ok := by native_decide

/-- Same key type with EMPTY sig: success = false → the truthy-final-stack
check fails with EVAL_FALSE (ref342.py S5b). Mutation caught: pushing 0x01
⇒ OK. -/
example : executeWitnessScript 100 [ByteArray.empty, pk33] 0
    (ByteArray.mk #[(0xac:UInt8)])
    default default ckGood SigVersion.tapscript
    = VerifyOutcome.fail ExecError.evalFalse := by native_decide

/-! ## S6 — CHECKSIGADD empty signature pushes `n` exactly (C13) -/

/-- `∅ <5> <pk32> CHECKSIGADD` → [0x05] (the +0 arm; ref342.py S6). Pinned at
`evalScriptBytes` level so the pushed VALUE is observed, not just the verdict.
Mutation caught: pushing n+1 ⇒ [0x06]. -/
example : evalScriptBytes 100 default default (ByteArray.mk #[(0xba:UInt8)])
    [pk32, ByteArray.mk #[(0x05:UInt8)], ByteArray.empty] ckGood SigVersion.tapscript
    { validationWeightLeftInit := true, validationWeightLeft := 50 }
    = .ok [ByteArray.mk #[(0x05:UInt8)]] := by rfl

/-- Contrast (X04 pins the end-to-end 0x06): nonempty sig ⇒ exactly [0x06] =
n+1, at the same level for a same-shape mutation pair. -/
example : evalScriptBytes 100 default default (ByteArray.mk #[(0xba:UInt8)])
    [pk32, ByteArray.mk #[(0x05:UInt8)], sig64] ckGood SigVersion.tapscript
    { validationWeightLeftInit := true, validationWeightLeft := 50 }
    = .ok [ByteArray.mk #[(0x06:UInt8)]] := by rfl

/-! ## S7 — the validation-weight budget (C14, SCR-168) -/

/-- Budget boundary: one sigop with budget slot exactly 50 lands at exactly 0 —
allowed (Core: `--validation_weight_left < 0` fails only BELOW zero;
ref342.py S7a). -/
example : evalChecksigTapscript default ckGood default sig64 pk32 (some 50)
    = .ok (true, some 0) := by rfl

/-- Budget slot 0 with a nonempty sig: −50 → below zero ⇒
TAPSCRIPT_VALIDATION_WEIGHT (ref342.py S7b). -/
example : evalChecksigTapscript default ckGood default sig64 pk32 (some 0)
    = .error ExecError.tapscriptValidationWeight := by rfl

/-- Unknown pubkey type with nonempty sig IS counted: budget 50 → exactly 0
(BIP342: "Signature opcodes with unknown public key type and non-empty
signature are also counted"; ref342.py S7c). -/
example : evalChecksigTapscript default ckGood default sig64 pk33 (some 50)
    = .ok (true, some 0) := by rfl

/-- End-to-end, the BIP342 budget through the REAL entry: script
`<pk33> CHECKSIG <pk33> CHECKSIGADD <pk33> CHECKSIGADD 3 NUMEQUAL`, three
nonempty (unknown-key) sigs, budget seeded vwSer+50 = 150 → 100 → 50 →
exactly 0 → OK (SCR-168 positive boundary; budget_e2e.py vwSer=100).
Mutation caught: exempting unknown-key sigops from the budget, or failing
the exactly-0 case ⇒ different verdict. -/
example : executeWitnessScript 100 [sig64, sig64, sig64] 100
    (ByteArray.mk (#[0x21] ++ (Array.replicate 33 (0x11:UInt8)) ++ #[0xac]
      ++ #[0x21] ++ (Array.replicate 33 (0x11:UInt8)) ++ #[0xba]
      ++ #[0x21] ++ (Array.replicate 33 (0x11:UInt8)) ++ #[0xba, 0x53, 0x9c]))
    default default ckGood SigVersion.tapscript = VerifyOutcome.ok := by native_decide

/-- Same script, vwSer = 99 (⇒ budget 149): the THIRD sigop lands at −1 ⇒
TAPSCRIPT_VALIDATION_WEIGHT (budget_e2e.py vwSer=99). Mutation caught:
any off-by-one in the −50 accounting flips this to OK. -/
example : executeWitnessScript 100 [sig64, sig64, sig64] 99
    (ByteArray.mk (#[0x21] ++ (Array.replicate 33 (0x11:UInt8)) ++ #[0xac]
      ++ #[0x21] ++ (Array.replicate 33 (0x11:UInt8)) ++ #[0xba]
      ++ #[0x21] ++ (Array.replicate 33 (0x11:UInt8)) ++ #[0xba, 0x53, 0x9c]))
    default default ckGood SigVersion.tapscript
    = VerifyOutcome.fail ExecError.tapscriptValidationWeight := by native_decide

/-! ## S8 — 520-byte element limit applies to the INITIAL stack (C18) -/

/-- One 521-byte initial-stack element, no SUCCESSx anywhere: PUSH_SIZE
(BIP342 Resource limits: "in the initial stack and in push opcodes").
Mutation caught: dropping the initial-stack half of the check ⇒ OK. -/
example : executeWitnessScript 100 [ByteArray.mk (Array.replicate 521 (0x00:UInt8))] 0
    (ByteArray.mk #[(0x51:UInt8)])
    default default ckGood SigVersion.tapscript
    = VerifyOutcome.fail ExecError.pushSize := by native_decide

/-! ## S9 — 65-byte signature hashtype byte rules (C16) -/

/-- 65-byte sig with trailing 0x00 (= SIGHASH_DEFAULT) is NOT a valid
tapscript signature — `none` at the hashtype split (BIP342: "sig[64] ≠ 0x00
and Verify(…)" — the conjunction fails; ref342.py S9). -/
example : schnorrHashtype sig65Default = none := by native_decide

/-- Contrast: trailing 0x01 splits into (body, 0x01) and IS validated. -/
example : schnorrHashtype sig65All
    = some (ByteArray.mk (Array.replicate 64 (0xab : UInt8)), (0x01:UInt8)) := by
  native_decide

/-- End-to-end verdict: the 0x00-trailing 65-byte sig fails at the checker even
with a perfect EC verifier and available txdata (mutation caught: falling
back to SIGHASH_ALL ⇒ true). -/
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some ByteArray.empty)
    ).checkSchnorrSignature sig65Default pk32 SigVersion.tapscript default = false := by
  native_decide

/-! ## Axiom pins (no sorryAx; native_decide confined to this Test module) -/

#print axioms Bitcoin.Interpreter.evalChecksigTapscript
#print axioms Bitcoin.Interpreter.checksigAddStep
#print axioms Bitcoin.Interpreter.executeWitnessScript
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrHashtype
#print axioms Bitcoin.Crypto.Seam.Entry.schnorrVerdict

end BitcoinProofs.Bip.B14
