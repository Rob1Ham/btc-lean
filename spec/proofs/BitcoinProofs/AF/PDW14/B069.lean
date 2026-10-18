import Bitcoin.Capstone.Block

/-! # B069 — PDW14, row BLK-069 (TOP-67).
`Bitcoin.Capstone.Block.bip34Ok` (Capstone/Block.lean:189).
S-evidence: `CapstoneBip34Cor` `bip34Ok_vacuous_below` (:307) +
`bip34Ok_push_prefix` (:321, the anchor run) — restated on the
PDW14 tag (BIP34 `bad-cb-height`, validation.cpp). -/

namespace BitcoinProofs.AF.PDW14

open Bitcoin.Capstone.Block Bitcoin.Data

/-! ## BLK-069 vacuity (flags-style): below the BIP34 activation
height 227931 the gate is vacuously true for EVERY coinbase — the
`if` takes the `else true` branch, the scriptSig is never inspected. -/
@[rule "BLK-069"]
theorem bip34Ok_vacuous_below (height : UInt32) (cb : Tx)
    (h : height < Bitcoin.Ledger.BIP34_HEIGHT) :
    bip34Ok height cb = true := by
  have h' : height.toNat < Bitcoin.Ledger.BIP34_HEIGHT.toNat :=
    UInt32.lt_iff_toNat_lt.mp h
  simp only [bip34Ok, if_neg (show ¬(Bitcoin.Ledger.BIP34_HEIGHT ≤ height) from by
    rw [UInt32.le_iff_toNat_le]; omega)]

/-! ## BLK-069 acceptance direction (the anchor run): when BIP34 is
active and the coinbase scriptSig *extends* the exact minimal push —
`push ++ rest` — the gate passes. -/
@[rule "BLK-069"]
theorem bip34Ok_push_prefix (height : UInt32) (cb : Tx) (txin : TxIn)
    (vinRest : List TxIn) (rest : ByteArray)
    (hact : Bitcoin.Ledger.BIP34_HEIGHT ≤ height)
    (hvin : cb.vin = txin :: vinRest)
    (hss : txin.scriptSig.bytes = cbHeightPush height ++ rest) :
    bip34Ok height cb = true := by
  simp only [bip34Ok, if_pos hact, hvin, List.getD_cons_zero, hss,
    ByteArray.extract_append_eq_left rfl, bytesBEq]
  simp

/-- BLK-069 converse/iff: with BIP34 active, `bip34Ok` accepts **iff** the
coinbase scriptSig's leading bytes are exactly the `cbHeightPush height`
prefix. This is the two-way form of the prefix gate (the forward direction
is `bip34Ok_push_prefix`). -/
@[rule "BLK-069"]
theorem bip34Ok_prefix_iff (height : UInt32) (cb : Tx) (txin : TxIn)
    (vinRest : List TxIn) (hact : Bitcoin.Ledger.BIP34_HEIGHT ≤ height)
    (hvin : cb.vin = txin :: vinRest) :
    bip34Ok height cb = true ↔
      bytesBEq (txin.scriptSig.bytes.extract 0 (cbHeightPush height).size)
        (cbHeightPush height) = true := by
  simp only [bip34Ok, if_pos hact, hvin, List.getD_cons_zero]

/-- info: 'BitcoinProofs.AF.PDW14.bip34Ok_prefix_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip34Ok_prefix_iff

end BitcoinProofs.AF.PDW14
