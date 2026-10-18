import Bitcoin.DataLaws.Interface
import Bitcoin.Crypto.Curve.Secp

/-! # PDW42.lean — TOP-206..208 (PDW42, 2026-10-17), claim b86bc7e

Status-debt band, route B (PDW32/PDW53 precedent): the target defs and
their sorry-free laws live in core; only the DB rows were never flipped.
Zero core writes; row-face theorems carry my `@[rule]` tags.

* **TXV-017** `txid = sha256d(serTx)` — ComputeHash (transaction.cpp:81-84)
  + witness independence + serialization congruence.
* **TXV-018** `wtxid` — ComputeWitnessHash (transaction.cpp:86-93): extended
  serialization when `hasWitness`, txid verbatim otherwise.
* **TPR-054** `liftX` — BIP340 lift_x: x-preservation, even y, on-curve,
  and `P ≤ x ⇒ none`.
-/

namespace BitcoinProofs.AF.PDW42

open Bitcoin.Data (Tx serTx WitnessStack)
open Bitcoin.Crypto.Seam (sha256d)
open Bitcoin.DataLaws (txid wtxid hasWitness serTxWithWitness)
open Bitcoin.Crypto.Curve.Secp (liftX RawOK P negN OnCurve
  liftX_ok liftX_snd liftX_even liftX_onCurve OnCurve_negN P_odd)
open Bitcoin.Crypto.Curve.Mod (subM)

/-- TXV-017: txid is exactly `sha256d` of the no-witness serialization. -/
@[rule "TXV-017"]
theorem txid_identity_face (tx : Tx) : txid tx = sha256d (serTx tx) :=
  Bitcoin.DataLaws.txid_eq_dsha256_serTx tx

/-- TXV-017: the txid is blind to witness data (BIP141 malleability fix). -/
@[rule "TXV-017"]
theorem txid_witness_independence_face (tx : Tx) (w : List WitnessStack) :
    txid { tx with witness := w } = txid tx :=
  Bitcoin.DataLaws.txid_witness_independence tx w

/-- TXV-017: txid is a congruence of the base serialization. -/
@[rule "TXV-017"]
theorem txid_ser_congr_face (a b : Tx) (h : serTx a = serTx b) :
    txid a = txid b :=
  Bitcoin.DataLaws.txid_congr a b h

/-- TXV-018: with witness data the wtxid hashes the extended serialization. -/
@[rule "TXV-018"]
theorem wtxid_witness_face (tx : Tx) (h : hasWitness tx = true) :
    wtxid tx = sha256d (serTxWithWitness tx) := by
  simp [wtxid, h]

/-- TXV-018: no witness ⇒ wtxid = txid (Core's `!HasWitness()` branch). -/
@[rule "TXV-018"]
theorem wtxid_no_witness_face (tx : Tx)
    (h : tx.witness.all (·.isEmpty)) : wtxid tx = txid tx :=
  Bitcoin.DataLaws.wtxid_eq_txid_iff_no_witness tx h

/-- TXV-018: wtxid congruence through the extended serialization. -/
@[rule "TXV-018"]
theorem wtxid_ser_congr_face (a b : Tx)
    (h : serTxWithWitness a = serTxWithWitness b) (hw : hasWitness a = hasWitness b)
    (ht : serTx a = serTx b) : wtxid a = wtxid b :=
  Bitcoin.DataLaws.wtxid_congr a b h hw ht

/-- TPR-054: `lift_x` preserves the requested x-coordinate (BIP340 §lift_x). -/
@[rule "TPR-054"]
theorem liftX_x_preserved {x x' y' : Nat} (h : liftX x = some (x', y')) : x' = x :=
  Bitcoin.Crypto.Curve.Secp.liftX_snd h

/-- TPR-054: the lifted point uses the even-y representative (BIP340). -/
@[rule "TPR-054"]
theorem liftX_even_y {x x' y' : Nat} (h : liftX x = some (x', y')) : y' % 2 = 0 :=
  Bitcoin.Crypto.Curve.Secp.liftX_even h

/-- TPR-054 (raw well-formedness): a lifted point has in-field
coordinates and lies in the curve's affine domain (`RawOK` is the
coordinate-bounds predicate, not the curve equation). -/
@[rule "TPR-054"]
theorem liftX_rawOK_face (x : Nat) : RawOK (liftX x) :=
  Bitcoin.Crypto.Curve.Secp.liftX_ok x

/-- TPR-054 (on-curve): a successfully lifted point satisfies the curve
equation `y² = x³ + 7 (mod p)`. This is the real curve-membership face;
the previous name on the `RawOK` theorem overstated it as "on curve". -/
@[rule "TPR-054"]
theorem liftX_onCurve_face {x x' y' : Nat} (h : liftX x = some (x', y')) :
    OnCurve x' y' :=
  Bitcoin.Crypto.Curve.Secp.liftX_onCurve h

/-- TPR-054: out-of-field x (`p ≤ x`) fails exactly as Core's lift_x does. -/
@[rule "TPR-054"]
theorem liftX_high_none (x : Nat) (h : P ≤ x) : liftX x = none := by
  simp [liftX, h]

/-! ## TPR-054 — the 32-byte x-only coordinate and its two parities -/

/-- `P` fits in 256 bits, so every canonical field representative — in
particular a successfully lifted x-only coordinate — is exactly a
32-byte BIP340 `XOnlyPubKey` payload. -/
theorem P_lt_two_pow_256 : P < 2 ^ 256 := by decide

/-- **TPR-054 (32-byte x-coordinate)**: `pubkey.cpp:XOnlyPubKey` stores the
x-coordinate as exactly 32 bytes and `lift_x` rejects `x ≥ p`; a point
returned by `liftX` therefore has a coordinate that fits the 32-byte
x-only encoding. -/
@[rule "TPR-054"]
theorem liftX_x_fits_32_bytes {x x' y' : Nat} (h : liftX x = some (x', y')) :
    x' < 2 ^ 256 := by
  have hok : RawOK (liftX x) := liftX_ok x
  rw [h] at hok
  exact Nat.lt_trans hok.1 P_lt_two_pow_256

/-- `−y` is an involution on canonical representatives. -/
theorem negN_negN {y : Nat} (hy : y < P) : negN (negN y) = y := by
  rcases Nat.eq_zero_or_pos y with h | h
  · subst h; simp [negN, subM]
  · unfold negN subM
    simp only [Nat.zero_add]
    rw [Nat.mod_eq_of_lt (show P - y < P by omega)]
    rw [show P - (P - y) = y from by omega, Nat.mod_eq_of_lt hy]

/-- **TPR-054 (both parities derivable)**: from a successful `lift_x` the
x-coordinate alone determines the even-y point `(x, y)` **and** its
negation `(x, p−y)`, which is also on the curve with the same 32-byte x;
the negation is an involution, and whenever `y ≠ 0` the second lift has
odd y — i.e. the two parity classes are both derivable from the x-only
key, exactly Core's `GetCPubKeys` (even-y canonical + odd-y sibling). -/
@[rule "TPR-054"]
theorem liftX_both_parities {x x' y' : Nat} (h : liftX x = some (x', y')) :
    x' = x ∧ OnCurve x' y' ∧ OnCurve x' (negN y') ∧
      y' % 2 = 0 ∧ (y' ≠ 0 → negN y' % 2 = 1) := by
  have hyP : y' < P := by
    have hok : RawOK (liftX x) := liftX_ok x
    rw [h] at hok
    exact hok.2
  refine ⟨liftX_snd h, liftX_onCurve h, OnCurve_negN hyP (liftX_onCurve h),
    liftX_even h, ?_⟩
  intro hy0
  unfold negN subM
  simp only [Nat.zero_add]
  rw [Nat.mod_eq_of_lt (show P - y' < P by omega)]
  have hPodd : P % 2 = 1 := P_odd
  have hy0' : y' % 2 = 0 := liftX_even h
  omega

/-- info: 'BitcoinProofs.AF.PDW42.P_lt_two_pow_256' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.P_lt_two_pow_256

/-- info: 'BitcoinProofs.AF.PDW42.liftX_x_fits_32_bytes' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_x_fits_32_bytes

/-- info: 'BitcoinProofs.AF.PDW42.negN_negN' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.negN_negN

/-- info: 'BitcoinProofs.AF.PDW42.liftX_both_parities' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_both_parities

end BitcoinProofs.AF.PDW42

/-- info: 'BitcoinProofs.AF.PDW42.txid_identity_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.txid_identity_face
/-- info: 'BitcoinProofs.AF.PDW42.txid_witness_independence_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.txid_witness_independence_face
/-- info: 'BitcoinProofs.AF.PDW42.txid_ser_congr_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.txid_ser_congr_face
/-- info: 'BitcoinProofs.AF.PDW42.wtxid_witness_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.wtxid_witness_face
/-- info: 'BitcoinProofs.AF.PDW42.wtxid_no_witness_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.wtxid_no_witness_face
/-- info: 'BitcoinProofs.AF.PDW42.wtxid_ser_congr_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.wtxid_ser_congr_face
/-- info: 'BitcoinProofs.AF.PDW42.liftX_x_preserved' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_x_preserved
/-- info: 'BitcoinProofs.AF.PDW42.liftX_even_y' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_even_y
/-- info: 'BitcoinProofs.AF.PDW42.liftX_rawOK_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_rawOK_face
/-- info: 'BitcoinProofs.AF.PDW42.liftX_onCurve_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_onCurve_face
/-- info: 'BitcoinProofs.AF.PDW42.liftX_high_none' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42.liftX_high_none
