import Bitcoin.Block.Params
import Bitcoin.Activation.Bip9

/-! # PDW27 BLK-004 + INV-122 — null-header and BIP9 signal row faces
(items TOP-131..135).

BLK-004 (`headerIsNull`, primitives/block.h:54-57): nBits == 0 iff the
header is null, plus the reject lane. INV-122 (`versionBitsSignals`,
versionbits_impl.h:79-82): the signal predicate is exactly
"top three bits = 001 AND bit set", with value-law projections.
Route B: zero core writes, tags ride these decls. -/

namespace BitcoinProofs.AF.PDW27

open Bitcoin.Block.Params

/-! ## BLK-004 — null header (PB:54-57) -/

/-- BLK-004 row face: `headerIsNull h = true ↔ h.bits = 0`. -/
@[rule "BLK-004"]
theorem headerIsNull_iff (h : Bitcoin.Chain.BlockHeader) :
    headerIsNull h = true ↔ h.bits = 0 := by
  simp [headerIsNull]

/-- BLK-004 decode lane: a null header's compact target is zero. -/
@[rule "BLK-004"]
theorem headerIsNull_compactTarget_zero (h : Bitcoin.Chain.BlockHeader)
    (hn : headerIsNull h = true) : Bitcoin.Chain.compactTarget h.bits = 0 := by
  rw [headerIsNull_iff h] at hn
  rw [hn]
  exact Bitcoin.Block.Params.compactTarget_zero

/-- BLK-004 reject lane: non-zero nBits ⇒ not a null header. -/
@[rule "BLK-004"]
theorem headerIsNull_nonzero (h : Bitcoin.Chain.BlockHeader) (hb : h.bits ≠ 0) :
    headerIsNull h = false := by
  simp [headerIsNull, hb]

/-! ## INV-122 — BIP9 signal predicate (versionbits_impl.h:79-82) -/

open Bitcoin.Activation

/-- INV-122 def-unfold. -/
@[rule "INV-122"]
theorem versionBitsSignals_eq (v : UInt32) (bit : Nat) :
    versionBitsSignals v bit =
      ((v &&& 0xE0000000) == 0x20000000 &&
        (((v >>> Nat.toUInt32 bit) &&& 1) == 1)) := rfl

/-- INV-122 iff-law: signal ⇔ top bits 001 ∧ bit set. -/
@[rule "INV-122"]
theorem versionBitsSignals_iff (v : UInt32) (bit : Nat) :
    versionBitsSignals v bit = true ↔
      (v &&& 0xE0000000 = 0x20000000 ∧
        (v >>> Nat.toUInt32 bit) &&& 1 = 1) := by
  simp [versionBitsSignals, Bool.and_eq_true, beq_iff_eq]

/-- INV-122 necessary lane: a signalling block has top bits exactly 001. -/
@[rule "INV-122"]
theorem versionBitsSignals_top_bits (v : UInt32) (bit : Nat)
    (h : versionBitsSignals v bit = true) :
    v &&& 0xE0000000 = 0x20000000 :=
  (versionBitsSignals_iff v bit).mp h |>.1

/-- INV-122 necessary lane: a signalling block has the deployment bit set. -/
@[rule "INV-122"]
theorem versionBitsSignals_bit_set (v : UInt32) (bit : Nat)
    (h : versionBitsSignals v bit = true) :
    (v >>> Nat.toUInt32 bit) &&& 1 = 1 :=
  (versionBitsSignals_iff v bit).mp h |>.2

/-- INV-122 reject lane: top bits ≠ 001 ⇒ no signal. -/
@[rule "INV-122"]
theorem versionBitsSignals_rejects (v : UInt32) (bit : Nat)
    (h : v &&& 0xE0000000 ≠ 0x20000000) : versionBitsSignals v bit = false := by
  simp [versionBitsSignals, h]

/-- INV-122 reject lane: unset deployment bit ⇒ no signal. -/
@[rule "INV-122"]
theorem versionBitsSignals_bit_unset (v : UInt32) (bit : Nat)
    (h : (v >>> Nat.toUInt32 bit) &&& 1 ≠ 1) : versionBitsSignals v bit = false := by
  simp [versionBitsSignals, h]

end BitcoinProofs.AF.PDW27
