import Bitcoin.Capstone.Block

/-! # PDW32.lean — RC25, items TOP-156..160
(PDW32, 2026-10-17). Claim 46712ab.

D-CAPBLK buried-gate band of `Bitcoin/Capstone/Block.lean`:

* **BLK-060/061/062** `versionOk` (Block.lean:198, validation.cpp:4123-4129)
  — the three buried version floors. Row-face theorems here: each gate's
  consequent is forced by the gate (bad-version lane).
* **INV-102** `versionOk` — the master conjunction iff (the exact three
  obligations) + the v1-after-BIP34 reject pin.
* **BLK-029** `cbLengthOk` (Block.lean:158, tx_check.cpp:55-58) — the
  coinbase scriptSig length bound [2,100] (`bad-cb-length`), genuine new
  theorem (no def-level proof existed).

Route B (PDW27-SCR-103 / PDW16 pattern): zero core writes, pins ⊆
[propext, Classical.choice, Quot.sound]. The proofs-side master file
`Theorems/CapstoneVersionCor.lean` is re-verified in `PDW32Check.lean`. -/

namespace BitcoinProofs.AF.PDW32

open Bitcoin.Capstone.Block

/-- BLK-060: once BIP34 is buried, a passing version is ≥ 2. -/
@[rule "BLK-060"]
theorem versionOk_bip34_face (height : UInt32) (version : Int32)
    (h : Bitcoin.Ledger.BIP34_HEIGHT ≤ height)
    (hv : versionOk height version = true) : 2 ≤ version := by
  have hall := hv
  simp only [versionOk, Bool.and_eq_true, decide_eq_true_eq, and_assoc] at hall
  exact hall.1 h

/-- BLK-061: once BIP66 (DERSIG) is buried, a passing version is ≥ 3. -/
@[rule "BLK-061"]
theorem versionOk_bip66_face (height : UInt32) (version : Int32)
    (h : Bitcoin.Activation.BIP66_HEIGHT ≤ height)
    (hv : versionOk height version = true) : 3 ≤ version := by
  have hall := hv
  simp only [versionOk, Bool.and_eq_true, decide_eq_true_eq, and_assoc] at hall
  exact hall.2.1 h

/-- BLK-062: once BIP65 (CLTV) is buried, a passing version is ≥ 4. -/
@[rule "BLK-062"]
theorem versionOk_bip65_face (height : UInt32) (version : Int32)
    (h : Bitcoin.Activation.BIP65_HEIGHT ≤ height)
    (hv : versionOk height version = true) : 4 ≤ version := by
  have hall := hv
  simp only [versionOk, Bool.and_eq_true, decide_eq_true_eq, and_assoc] at hall
  exact hall.2.2 h

/-- INV-102: the gate is exactly the conjunction of the three buried floors. -/
@[rule "INV-102"]
theorem versionOk_row_iff (height : UInt32) (version : Int32) :
    versionOk height version = true ↔
      (Bitcoin.Ledger.BIP34_HEIGHT ≤ height → version ≥ 2) ∧
      (Bitcoin.Activation.BIP66_HEIGHT ≤ height → version ≥ 3) ∧
      (Bitcoin.Activation.BIP65_HEIGHT ≤ height → version ≥ 4) := by
  simp only [versionOk, Bool.and_eq_true, decide_eq_true_eq, and_assoc]

/-- INV-102 reject lane: v1 is `bad-version` at every BIP34-active height. -/
theorem versionOk_v1_reject (height : UInt32)
    (h : Bitcoin.Ledger.BIP34_HEIGHT ≤ height) : versionOk height 1 = false := by
  have hne : versionOk height 1 ≠ true := by
    intro hv
    have := versionOk_bip34_face height 1 h hv
    exact absurd this (by decide)
  exact (Bool.not_eq_true _).mp hne

/-- BLK-029: the coinbase scriptSig length check is exactly `2 ≤ n ∧ n ≤ 100`. -/
@[rule "BLK-029"]
theorem cbLengthOk_iff (cb : Bitcoin.Data.Tx) :
    cbLengthOk cb = true ↔
      2 ≤ (cb.vin.getD 0 ⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes.size ∧
      (cb.vin.getD 0 ⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes.size ≤ 100 := by
  simp only [cbLengthOk, Bool.and_eq_true, decide_eq_true_eq]
  rfl

/-- BLK-029 reject lane: a coinbase scriptSig shorter than 2 bytes fails. -/
theorem cbLengthOk_short (cb : Bitcoin.Data.Tx)
    (h : (cb.vin.getD 0 ⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes.size < 2) :
    cbLengthOk cb = false := by
  have hn : ¬ (2 ≤ (cb.vin.getD 0 ⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes.size) :=
    Nat.not_le.mpr h
  by_cases hb : cbLengthOk cb = true
  · exact absurd ((cbLengthOk_iff cb).mp hb).1 hn
  · exact (Bool.not_eq_true _).mp hb

/-- BLK-029 reject lane: a coinbase scriptSig longer than 100 bytes fails. -/
theorem cbLengthOk_long (cb : Bitcoin.Data.Tx)
    (h : 100 < (cb.vin.getD 0 ⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes.size) :
    cbLengthOk cb = false := by
  have hn : ¬ ((cb.vin.getD 0 ⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes.size ≤ 100) :=
    Nat.not_le.mpr h
  by_cases hb : cbLengthOk cb = true
  · exact absurd ((cbLengthOk_iff cb).mp hb).2 hn
  · exact (Bool.not_eq_true _).mp hb

end BitcoinProofs.AF.PDW32
