import Bitcoin.Invariants.RC02
import Bitcoin.TxValidation.Interface

/-! # PDW48 — TOP-161..165, BIP113 × BIP68 finality band (part 2)

INV-017 (BIP68 enable gate), INV-020 (masked relative operand) and
INV-021 (`EvaluateSequenceLocks` verdict), incl. the cross-module
coherence with X09's `TxValidation.evaluateSequenceLocks`/`sequenceLocksOk`.
Route B (zero core writes). -/

namespace BitcoinProofs.AF.PDW48

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.Invariants.RC02 Bitcoin.TxValidation

/-- INV-017: Core's gate — wire version ≥ 2 AND the CSV flag. -/
@[rule "INV-017"]
theorem bip68Enabled_row_iff (v : Int32) (f : Bool) :
    bip68Enabled v f = true ↔ 2 ≤ v.toUInt32.toNat ∧ f = true :=
  bip68Enabled_iff v f

/-- INV-017: flag clear ⇒ BIP68 off for every version. -/
@[rule "INV-017"]
theorem bip68Enabled_flag_off (v : Int32) : bip68Enabled v false = false :=
  bip68Enabled_zero_flag v

/-- INV-017: version 1 never enables BIP68. -/
@[rule "INV-017"]
theorem bip68Enabled_v1 (f : Bool) : bip68Enabled 1 f = false := by
  unfold bip68Enabled
  have h : ¬ (2 ≤ (1 : Int32).toUInt32.toNat) := by decide
  rw [decide_eq_false_iff_not.mpr h]
  rfl

/-- INV-017: the wire value 0xFFFFFFFF is `version = -1` in the signed
scaffold and is **enabled** in Core (unsigned comparison). -/
@[rule "INV-017"]
theorem bip68Enabled_wire_high : bip68Enabled (-1 : Int32) true = true := by
  decide

/-- INV-020: the operand is exactly the low 16 bits. -/
@[rule "INV-020"]
theorem seqRelative_mod (s : UInt32) : seqRelative s = s.toNat % 65536 :=
  seqRelative_eq_mod s

/-- INV-020: equality of relative locktimes iff equality of low 16 bits. -/
@[rule "INV-020"]
theorem seqRelative_eq_iff (s t : UInt32) :
    seqRelative s = seqRelative t ↔ s.toNat % 65536 = t.toNat % 65536 := by
  rw [seqRelative_eq_mod, seqRelative_eq_mod]

/-- INV-020: Core boundary pins (`& 0xffff`). -/
@[rule "INV-020"]
theorem seqRelative_pins : seqRelative 0 = 0 ∧ seqRelative 0xFFFFFFFF = 65535 := by
  decide

/-- INV-020: the masked operand is the whole of the height-domain lock:
`coinHeight + (seq & 0xffff) ≤ H`. -/
@[rule "INV-020"]
theorem seqRelative_height_lock (coinHeight : Nat) (s : UInt32) (H : Nat) :
    seqHeightOk coinHeight s H = true ↔ coinHeight + seqRelative s ≤ H :=
  seqHeightOk_iff coinHeight s H

/-- INV-021: the strict lock-pair verdict. -/
@[rule "INV-021"]
theorem evalSequenceLocks_row_iff (blockHeight blockTime minH minT : Int) :
    evalSequenceLocks blockHeight blockTime minH minT = true ↔
      minH < blockHeight ∧ minT < blockTime :=
  evalSequenceLocks_iff blockHeight blockTime minH minT

/-- INV-021: the RC02 mirror is the X09 seam verdict on the same pair. -/
@[rule "INV-021"]
theorem evalSequenceLocks_agrees (blockHeight blockTime : Int) (p : Int × Int) :
    evalSequenceLocks blockHeight blockTime p.1 p.2 =
      evaluateSequenceLocks blockHeight blockTime p := rfl

/-- INV-021: end-to-end — BIP68 off ⇒ the whole `SequenceLocks` gate passes
at any non-negative evaluation point (the (-1,-1) sentinel). -/
@[rule "INV-021"]
theorem sequenceLocksOk_disabled_pass (tx : Tx) (csv : Bool)
    (prevData : List (Int × Int)) (blockHeight blockTime : Int)
    (hoff : bip68Enabled tx.version csv = false)
    (hH : 0 ≤ blockHeight) (hT : 0 ≤ blockTime) :
    sequenceLocksOk tx csv prevData blockHeight blockTime = true := by
  unfold sequenceLocksOk
  rw [calculateSequenceLocks_disabled _ _ _ hoff, evaluateSequenceLocks_eq]
  omega

/-- INV-021: end-to-end — BIP68 on ⇒ the verdict is the strict pair of the
input fold's running maxima. -/
@[rule "INV-021"]
theorem sequenceLocksOk_enabled_iff (tx : Tx) (csv : Bool)
    (prevData : List (Int × Int)) (blockHeight blockTime : Int)
    (hon : bip68Enabled tx.version csv = true) :
    sequenceLocksOk tx csv prevData blockHeight blockTime = true ↔
      (seqLockFold tx.vin prevData).1 < blockHeight ∧
        (seqLockFold tx.vin prevData).2 < blockTime := by
  unfold sequenceLocksOk
  rw [calculateSequenceLocks_enabled _ _ _ hon, evaluateSequenceLocks_eq]

end BitcoinProofs.AF.PDW48
