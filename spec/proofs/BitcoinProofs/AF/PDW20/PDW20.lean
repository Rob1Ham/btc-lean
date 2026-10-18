import Bitcoin.Invariants.RC10
import Bitcoin.Activation.Bip9
import Bitcoin.DataLaws.Laws

/-! # PDW20.lean — items TOP-96..100
(PDW20, RC21/RC26, 2026-10-17).

Five sorry-free row-face groups, one per claimed rules.yaml row:

* **INV-109** `chainLinkOk` (RC10.lean:27) → `chainLinkOk_iff`
  (byte-linkage ⇔ prev-hash, both halves of the accepted-header law).
* **INV-115** `coinMetaEncode` (RC10.lean:150) → `coinMeta_roundtrip`
  + `coinMeta_encode_decode` (two-sided height/coinbase codec inverse)
  + `coinMeta_lt_two_pow_32` (31-bit height fits UInt32).
* **BLK-081** `mainnetTestdummy` (Bip9.lean:207) →
  `mainnet_testdummy_table` (bit 28 / NEVER_ACTIVE / 1815 / 2016) +
  `mainnet_testdummy_dormant` (never activates) +
  `mainnet_deployments_singleton`.
* **INV-018** `seqIsDisabled` (DataLaws/Laws.lean:245) →
  `seqIsDisabled_bit31_iff` (disable ⇔ top bit) +
  `seqDisabled_of_ge` + `seqNotDisabled_of_lt` (both mask halves).
* **SWT-018** `WITNESS_SCALE_FACTOR` (DataLaws/Laws.lean:69) →
  `witness_scale_factor_eq_four` + `legacy_units_of_weight`.

Route B (PDW11/PDW12/PDW15/PDW16 pattern): zero core writes; the
`@[rule]` tags ride these theorems; yaml lean_targets drift-fixed to
the full names below. Module deliberately NOT imported by the
`BitcoinProofs` root (PDW12 isolation pattern). Axiom pins (⊆ charter
trio) are guarded with expected footprints in `PDW20Guards.lean`.
-/

namespace BitcoinProofs.AF.PDW20

open Bitcoin.Chain Bitcoin.Data Bitcoin.Invariants.RC10 Bitcoin.Ledger
open Bitcoin.Activation Bitcoin.DataLaws

/-! ## INV-109 — prev-block-hash linkage (validation.cpp:4221–4231) -/

@[rule "INV-109"]
theorem chainLinkOk_iff (prev : ByteArray) (h : BlockHeader) :
    chainLinkOk prev h = true ↔ h.hashPrevBlock = prev :=
  ⟨fun hok => Bitcoin.Ledger.bytesBEq_eq_of_true _ _ hok,
   fun heq => by
     unfold chainLinkOk
     rw [heq]
     exact Bitcoin.Ledger.bytesBEq_self prev⟩

/-! ## INV-115 — 31-bit height + 1-bit coinbase codec (coins.h:77–96) -/

@[rule "INV-115"]
theorem coinMeta_roundtrip (height : Nat) (coinbase : Bool) :
    coinMetaDecode (coinMetaEncode height coinbase) = (height, coinbase) :=
  coinMetaDecode_encode height coinbase

@[rule "INV-115"]
theorem coinMeta_encode_decode (code : Nat) :
    coinMetaEncode (coinMetaDecode code).1 (coinMetaDecode code).2 = code := by
  unfold coinMetaEncode coinMetaDecode
  by_cases hc : code % 2 = 1
  · have hb : (code % 2 == 1) = true := by simp [hc]
    rw [hb]; simp; omega
  · have h0 : code % 2 = 0 := by omega
    have hb : (code % 2 == 1) = false := by simp [h0]
    rw [hb]; simp; omega

@[rule "INV-115"]
theorem coinMeta_lt_two_pow_32 (height : Nat) (coinbase : Bool)
    (hh : height < 2 ^ 31) : coinMetaEncode height coinbase < 2 ^ 32 :=
  coinMetaEncode_lt height coinbase hh

/-! ## BLK-081 — mainnet deployment table + dormancy (CP:128–134) -/

@[rule "BLK-081"]
theorem mainnet_testdummy_table :
    mainnetTestdummy.bit = 28 ∧ mainnetTestdummy.start = BIP9_NEVER_ACTIVE ∧
    mainnetTestdummy.timeout = BIP9_ALWAYS_ACTIVE ∧
    mainnetTestdummy.minActivation = 0 ∧ mainnetTestdummy.threshold = 1815 ∧
    mainnetTestdummy.period = 2016 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

@[rule "BLK-081"]
theorem mainnet_testdummy_dormant (count : UInt32 → UInt32) (h : UInt32) :
    thresholdState mainnetTestdummy.start mainnetTestdummy.timeout
      mainnetTestdummy.threshold mainnetTestdummy.period count h = .failed :=
  bip9_never_active _ _ _ _ h

@[rule "BLK-081"]
theorem mainnet_deployments_singleton :
    mainnetDeployments = [mainnetTestdummy] := rfl

/-! ## INV-018 — BIP68 disable bit = sequence top bit (tx_verify.cpp:71-75) -/

@[rule "INV-018"]
theorem seqIsDisabled_bit31_iff (s : UInt32) :
    seqIsDisabled s = true ↔ 2147483648 ≤ s.toNat :=
  Bitcoin.DataLaws.seqIsDisabled_iff s

@[rule "INV-018"]
theorem seqDisabled_of_ge (s : UInt32) (h : 2147483648 ≤ s.toNat) :
    seqIsDisabled s = true :=
  Bitcoin.DataLaws.seqIsDisabled_of_ge s h

@[rule "INV-018"]
theorem seqNotDisabled_of_lt (s : UInt32) (h : s.toNat < 2147483648) :
    seqIsDisabled s = false :=
  Bitcoin.DataLaws.seqNotDisabled_of_lt s h

/-! ## SWT-018 — WITNESS_SCALE_FACTOR = 4 (consensus.h:21) -/

@[rule "SWT-018"]
theorem witness_scale_factor_eq_four : WITNESS_SCALE_FACTOR = 4 := rfl

@[rule "SWT-018"]
theorem legacy_units_of_weight (weight : Nat) :
    weight / WITNESS_SCALE_FACTOR = weight / 4 := by
  rw [witness_scale_factor_eq_four]

end BitcoinProofs.AF.PDW20
