import Bitcoin.Interpreter.Defs
import Bitcoin.Block.Sigops
import Bitcoin.TxValidation.Interface
import Bitcoin.Crypto.Taproot.Program

/-! # PDW77 — row faces TOP-406..410 (RC30 endgame)

Route B promotion bank. Zero core writes; tags ride these restatements.
* INV-066 `p2shInner` — redeemScript (last scriptSig item) verdict.
* INV-075 `verifyWitnessProgram` — BIP341 annex strip + hash into keypath.
* INV-035 `legacySigOpCountTx` — witness-independent legacy sigop folds.
* TXV-040 `bip68HeightOk` — height gate iff + CSV-flag-off pass.
* TXV-020 `haveInputs` — all prevouts resolve iff true.
-/

namespace BitcoinProofs.AF.PDW77

open Bitcoin.Data (WitnessStack compactSizeEnc)
open Bitcoin.Numeric (castToBool)
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Interpreter
open Bitcoin.Block.Sigops

/-! ## INV-066 — P2SH inner evaluation -/

/-- INV-066: with a push-only scriptSig the saved top item is the
redeemScript; a successful truthy inner evaluation is `.ok`. -/
@[rule "INV-066"]
theorem p2shInner_redeem_ok (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss p : ByteArray) (rest witness : List ByteArray)
    (chk : ScriptChecker) (ops : List WireOp) (stack : Stack)
    (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hev : evalScriptBytes fuel flags pol p rest chk .base default = .ok stack)
    (hne : stack ≠ []) (htrue : castToBool (stack[0]?.getD default) = true)
    (hw : flags.witness = false) :
    p2shInner fuel flags pol ss (p :: rest) witness chk = .ok := by
  unfold p2shInner
  rw [hparse]
  simp [hpush, hev, hne, htrue, hw]

/-- INV-066: an inner-evaluation error is propagated verbatim. -/
@[rule "INV-066"]
theorem p2shInner_redeem_eval_fail (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss p : ByteArray) (rest witness : List ByteArray)
    (chk : ScriptChecker) (ops : List WireOp) (e : ExecError)
    (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hev : evalScriptBytes fuel flags pol p rest chk .base default = .error e) :
    p2shInner fuel flags pol ss (p :: rest) witness chk = .fail e := by
  unfold p2shInner
  rw [hparse]
  simp [hpush, hev]

/-- INV-066: a falsy inner result is `evalFalse` (Core's cleanstack truth test). -/
@[rule "INV-066"]
theorem p2shInner_redeem_false (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss p : ByteArray) (rest witness : List ByteArray)
    (chk : ScriptChecker) (ops : List WireOp) (stack : Stack)
    (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hev : evalScriptBytes fuel flags pol p rest chk .base default = .ok stack)
    (hne : stack ≠ []) (hfalse : castToBool (stack[0]?.getD default) = false) :
    p2shInner fuel flags pol ss (p :: rest) witness chk = .fail .evalFalse := by
  unfold p2shInner
  rw [hparse]
  simp [hpush, hev, hne, hfalse]

/-! ## INV-075 — BIP341 annex parse

**Residual (accepted, disclosed):** `Bitcoin.Interpreter.verifyWitnessProgram`
(Defs.lean:1247 and the pin at :1632) models the annex digest as
`hashSha256 annex` — a raw single SHA256 over the annex bytes — whereas
BIP341 / Core's `HashWriter << Span(annex)` hashes
`SHA256(CompactSize(len(annex)) ‖ annex)` (interpreter.cpp:1964 +
1554-1556). The theorem below faithfully mirrors the current `Defs`
model, so it inherits that model drift; it does NOT establish the Core
annex digest. The correct computation already exists as
`Bitcoin.Crypto.Taproot.Program.annexHash` (TPR-006) and is pinned as
the companion theorem `annexHash_compactSize_correct` below. Closing the
gap requires changing `Defs.lean`, which is outside this area's write
scope. -/

/-- INV-075 (CompactSize-correct companion): the TPR-006 annex hash is
`SHA256(CompactSize(len) ‖ annex)`, including the 0x50 tag byte. This is
the digest the `Defs` model above should use; it is proved here so the
row carries a correct, independently checked target as well as the
faithful model statement. -/
@[rule "INV-075"]
theorem annexHash_compactSize_correct (annex : ByteArray) :
    Bitcoin.Crypto.Taproot.Program.annexHash annex =
      Bitcoin.Crypto.Seam.Hash.Sha256.sha256
        (compactSizeEnc annex.size ++ annex) := rfl

/-- INV-075: witness `[sig, annex]` with a nonempty `0x50`-tagged last
item is an annex spend: the annex is hashed into `ScriptExecutionData`,
stripped from the stack, and the remaining single item is the key-path
signature checked against the output key. The digest is the current
`Defs` model (`hashSha256 annex`), NOT the CompactSize-correct one — see
the residual note above. -/
@[rule "INV-075"]
theorem verifyWitnessProgram_annex_keypath (fuel : Nat) (sig annex program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (htap : flags.taproot = true) (h32 : program.size = 32)
    (hnonempty : annex.size ≠ 0) (htag : (byteOr annex 0).toNat = ANNEX_TAG) :
    verifyWitnessProgram fuel [sig, annex] 1 program flags pol chk false =
      if chk.base.checkSchnorrSignature sig program SigVersion.taproot
          { (default : ScriptExecutionData) with
            annexInit := true, annexPresent := true,
            annexHash := hashSha256 annex }
        then VerifyOutcome.ok else VerifyOutcome.fail .schnorrSig := by
  simp [verifyWitnessProgram, htap, h32, hnonempty, htag]

/-! ## INV-035 — legacy sigop composition -/

/-- INV-035: the legacy count reads only scriptSig/scriptPubKey bytes —
witness data never contributes (fAccurate=false). -/
@[rule "INV-035"]
theorem legacySigOpCountTx_witness_indep (tx : Bitcoin.Data.Tx) (w : List WitnessStack) :
    legacySigOpCountTx { tx with witness := w } = legacySigOpCountTx tx := by
  cases tx
  rfl

/-- INV-035: CHECKSIG/CHECKSIGVERIFY count 1, CHECKMULTISIG(VERIFY) 20. -/
@[rule "INV-035"]
theorem legacySigOpCountScript_weights :
    legacySigOpCountScript ⟨ByteArray.mk #[0xac]⟩ = 1 ∧
    legacySigOpCountScript ⟨ByteArray.mk #[0xad]⟩ = 1 ∧
    legacySigOpCountScript ⟨ByteArray.mk #[0xae]⟩ = 20 ∧
    legacySigOpCountScript ⟨ByteArray.mk #[0xaf]⟩ = 20 := by
  decide

/-! ## TXV-040 — BIP68 height gate -/

/-- TXV-040: the height gate is true iff CSV is disabled at `tx.version`
or the height-domain sequence locks pass. -/
@[rule "TXV-040"]
theorem bip68HeightOk_true_iff (tx : Bitcoin.Data.Tx) (u : Bitcoin.Ledger.UtxoSet)
    (csv : Bool) (H : Int) (hH : 0 ≤ H) :
    Bitcoin.TxValidation.bip68HeightOk tx u csv H = true ↔
      (Bitcoin.DataLaws.bip68Enabled tx.version csv = false ∨
        Bitcoin.TxValidation.vinHeightOk tx.vin
          (Bitcoin.TxValidation.prevHeightData tx u) H) :=
  Bitcoin.TxValidation.bip68HeightOk_iff tx u csv H hH

/-- TXV-040: with CSV inactive and a positive height the gate passes. -/
@[rule "TXV-040"]
theorem bip68HeightOk_csv_off (tx : Bitcoin.Data.Tx) (u : Bitcoin.Ledger.UtxoSet)
    (H : Int) (hH : 0 < H) :
    Bitcoin.TxValidation.bip68HeightOk tx u false H = true := by
  rw [Bitcoin.TxValidation.bip68HeightOk_iff tx u false H (by omega)]
  exact Or.inl (by simp [Bitcoin.DataLaws.bip68Enabled])

/-! ## TXV-020 — HaveInputs -/

/-- TXV-020: `haveInputs` is exactly "every input's prevout resolves". -/
@[rule "TXV-020"]
theorem haveInputs_true_iff (tx : Bitcoin.Data.Tx) (u : Bitcoin.Ledger.UtxoSet) :
    Bitcoin.TxValidation.haveInputs tx u = true ↔
      ∀ i ∈ tx.vin, ∃ c, u i.prevout = some c := by
  unfold Bitcoin.TxValidation.haveInputs
  rw [List.all_eq_true]
  constructor
  · intro h i hi
    have hi' := h i hi
    cases hv : u i.prevout with
    | none => simp [hv] at hi'
    | some c => exact ⟨c, rfl⟩
  · intro h i hi
    obtain ⟨c, hc⟩ := h i hi
    simp [hc]

/-- TXV-020 fail-closed: false means some prevout is missing. -/
@[rule "TXV-020"]
theorem haveInputs_false_iff (tx : Bitcoin.Data.Tx) (u : Bitcoin.Ledger.UtxoSet) :
    Bitcoin.TxValidation.haveInputs tx u = false ↔
      ∃ i ∈ tx.vin, u i.prevout = none := by
  unfold Bitcoin.TxValidation.haveInputs
  rw [List.all_eq_false]
  constructor
  · rintro ⟨i, hi, hnone⟩
    cases h : u i.prevout with
    | none => exact ⟨i, hi, h⟩
    | some c => simp [h] at hnone
  · rintro ⟨i, hi, hv⟩
    exact ⟨i, hi, by simp [hv]⟩

end BitcoinProofs.AF.PDW77

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW77.p2shInner_redeem_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.p2shInner_redeem_ok

/-- info: 'BitcoinProofs.AF.PDW77.p2shInner_redeem_eval_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.p2shInner_redeem_eval_fail

/-- info: 'BitcoinProofs.AF.PDW77.p2shInner_redeem_false' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.p2shInner_redeem_false

/-- info: 'BitcoinProofs.AF.PDW77.annexHash_compactSize_correct' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.annexHash_compactSize_correct

/-- info: 'BitcoinProofs.AF.PDW77.verifyWitnessProgram_annex_keypath' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.verifyWitnessProgram_annex_keypath

/-- info: 'BitcoinProofs.AF.PDW77.legacySigOpCountTx_witness_indep' does not depend on any axioms -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.legacySigOpCountTx_witness_indep

/-- info: 'BitcoinProofs.AF.PDW77.legacySigOpCountScript_weights' does not depend on any axioms -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.legacySigOpCountScript_weights

/-- info: 'BitcoinProofs.AF.PDW77.bip68HeightOk_true_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.bip68HeightOk_true_iff

/-- info: 'BitcoinProofs.AF.PDW77.bip68HeightOk_csv_off' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.bip68HeightOk_csv_off

/-- info: 'BitcoinProofs.AF.PDW77.haveInputs_true_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.haveInputs_true_iff

/-- info: 'BitcoinProofs.AF.PDW77.haveInputs_false_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW77.haveInputs_false_iff
