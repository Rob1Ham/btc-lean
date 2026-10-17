import Bitcoin.Ledger.Utxo
import Bitcoin.Invariants.RC10

/-! # PDW18 — BLK-101 (route B: tags ride MY theorems, zero core writes)

Coin record laws: `Bitcoin.Ledger.Coin` carries value + creation height +
coinbase bit + scriptPubKey (coins.h:45-72 @cce32b168; the 31+1-bit
on-disk packing is INV-115's `coinMetaEncode` and is out of scope here
= honest model gap). Eta + constructor injectivity; the core structure
and its stacked tag (`@[rule "BLK-101", rule "INV-114"]`, Utxo.lean:21)
stay untouched. -/

namespace BitcoinProofs.AF.PDW18

open Bitcoin.Ledger Bitcoin.Data

@[rule "BLK-101"]
theorem Coin_eta (c : Coin) :
    c = ⟨c.value, c.height, c.isCoinbase, c.scriptPubKey⟩ := by
  cases c
  rfl

theorem Coin_mk_inj {v₁ v₂ : Amount} {h₁ h₂ : UInt32} {b₁ b₂ : Bool}
    {s₁ s₂ : Script} :
    (⟨v₁, h₁, b₁, s₁⟩ : Coin) = ⟨v₂, h₂, b₂, s₂⟩ ↔
      v₁ = v₂ ∧ h₁ = h₂ ∧ b₁ = b₂ ∧ s₁ = s₂ := by
  simp [Coin.mk.injEq]

theorem Coin_coinbase_bit (c : Coin) :
    (c.isCoinbase = true ∨ c.isCoinbase = false) := by
  cases c.isCoinbase <;> simp

/-- BLK-101 (coins.h:45-89 @cce32b168): the `Coin` record is exactly
Core's four fields — value, scriptPubKey, creation height, coinbase bit —
and the 31+1-bit metadata word packs them: the 31-bit height field and
the 1-bit coinbase flag encode to a 32-bit code word
(`(height << 1) | coinbase`), decode back to the record's fields, and any
height below `2^31` stays inside `2^32`.  So the on-disk width claim is
stated, not elided. -/
@[rule "BLK-101"]
theorem Coin_fields_31_1 (c : Coin) :
    c = ⟨c.value, c.height, c.isCoinbase, c.scriptPubKey⟩ ∧
    Bitcoin.Invariants.RC10.coinMetaDecode
        (Bitcoin.Invariants.RC10.coinMetaEncode c.height.toNat c.isCoinbase) =
      (c.height.toNat, c.isCoinbase) ∧
    (c.height.toNat < 2 ^ 31 →
      Bitcoin.Invariants.RC10.coinMetaEncode c.height.toNat c.isCoinbase < 2 ^ 32) := by
  refine ⟨?_, Bitcoin.Invariants.RC10.coinMetaDecode_encode _ _,
    fun hh => Bitcoin.Invariants.RC10.coinMetaEncode_lt _ _ hh⟩
  cases c
  rfl

/-- BLK-101: the metadata word's two projections are the height (31 bits)
and the coinbase bit (1 bit) — `code / 2` and `code % 2`. -/
@[rule "BLK-101"]
theorem Coin_meta_fields (c : Coin) :
    Bitcoin.Invariants.RC10.coinMetaEncode c.height.toNat c.isCoinbase / 2 =
        c.height.toNat ∧
      Bitcoin.Invariants.RC10.coinMetaEncode c.height.toNat c.isCoinbase % 2 =
        (if c.isCoinbase then 1 else 0) := by
  unfold Bitcoin.Invariants.RC10.coinMetaEncode
  cases c.isCoinbase <;> simp <;> omega

end BitcoinProofs.AF.PDW18
