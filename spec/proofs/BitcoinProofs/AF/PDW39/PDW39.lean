import Bitcoin.Block.Params

/-! # PDW39.lean — TOP-191..195, D-PARAMS residual band

Route B: zero core writes; row theorems carry `@[rule]` tags and restate
the Core-facing faces of `Bitcoin/Block/Params.lean`. -/

namespace BitcoinProofs.AF.PDW39

open Bitcoin.Block.Params Bitcoin.Data Bitcoin.Ledger
open Bitcoin.Capstone.Merkle

/-! ## BLK-125 — the 64-byte-tx mutation guard -/

@[rule "BLK-125"]
theorem mutated64ByteTx_cons_iff (cb : Tx) (rest : List Tx) :
    mutated64ByteTx (cb :: rest) = true ↔
      cb.isCoinBase = false ∧ ∃ t ∈ cb :: rest, serTxSize t = 64 := by
  by_cases hc : cb.isCoinBase = true
  · simp [mutated64ByteTx, hc]
  · have hcf : cb.isCoinBase = false := by simpa using hc
    simp [mutated64ByteTx, hcf, List.any_eq_true]

@[rule "BLK-125"]
theorem mutated64ByteTx_mutated_witness (cb : Tx) (rest : List Tx)
    (h : mutated64ByteTx (cb :: rest) = true) :
    cb.isCoinBase = false ∧ ∃ t ∈ cb :: rest, serTxSize t = 64 :=
  (mutated64ByteTx_cons_iff cb rest).mp h

/-! ## BLK-129 — constant-space merkle path replay -/

@[rule "BLK-129"]
theorem merklePathRoot_sound_row (leaf : ByteArray) (path : List (Bool × ByteArray)) :
    merklePathVerify (merklePathRoot leaf path) leaf path = true :=
  merklePathRoot_sound leaf path

@[rule "BLK-129"]
theorem merklePathRoot_append (leaf : ByteArray) (p q : List (Bool × ByteArray)) :
    merklePathRoot leaf (p ++ q) = merklePathRoot (merklePathRoot leaf p) q := by
  unfold merklePathRoot
  rw [List.foldl_append]

@[rule "BLK-129"]
theorem merklePathRoot_singleton_left (leaf : ByteArray) (h : ByteArray) :
    merklePathRoot leaf [(true, h)] = pairHash h leaf := by
  simp [merklePathRoot]

@[rule "BLK-129"]
theorem merklePathRoot_singleton_right (leaf : ByteArray) (h : ByteArray) :
    merklePathRoot leaf [(false, h)] = pairHash leaf h := by
  simp [merklePathRoot]

/-! ## BLK-065 — cached header verdict -/

@[rule "BLK-065"]
theorem cachedVerdict_genesis_row (idx : Nat → Option IndexEntry) (self : Nat) :
    cachedVerdict idx self true = some true := rfl

@[rule "BLK-065"]
theorem cachedVerdict_unknown (idx : Nat → Option IndexEntry) (self : Nat)
    (h : idx self = none) : cachedVerdict idx self false = none := by
  simp [cachedVerdict, h]

@[rule "BLK-065"]
theorem cachedVerdict_iff (idx : Nat → Option IndexEntry) (self : Nat) (g b : Bool) :
    cachedVerdict idx self g = some b ↔
      (g = true ∧ b = true) ∨
      (g = false ∧ ∃ e, idx self = some e ∧ e.valid = b) := by
  constructor
  · intro h
    cases g with
    | true =>
      refine Or.inl ⟨rfl, ?_⟩
      rw [cachedVerdict_genesis_row] at h
      exact (Option.some.inj h).symm
    | false =>
      cases hi : idx self with
      | none =>
        rw [cachedVerdict_unknown idx self hi] at h
        exact absurd h (by simp)
      | some e =>
        refine Or.inr ⟨rfl, ⟨e, rfl, ?_⟩⟩
        rw [cachedVerdict_known idx self e hi] at h
        exact Option.some.inj h
  · rintro (⟨rfl, hb⟩ | ⟨rfl, ⟨e, hi, hb⟩⟩)
    · subst hb; exact cachedVerdict_genesis_row idx self
    · subst hb; exact cachedVerdict_known idx self e hi

/-! ## BLK-128 — BIP141 reserved-value fill -/

@[rule "BLK-128"]
theorem reservedValueFill_fill (a : Bool) (r : ByteArray)
    (ha : a = true) (hr : r.size = 0) : reservedValueFill a r = zeroBytes 32 := by
  simp [reservedValueFill, ha, hr]

@[rule "BLK-128"]
theorem reservedValueFill_inactive (r : ByteArray) :
    reservedValueFill false r = r := by simp [reservedValueFill]

@[rule "BLK-128"]
theorem reservedValueFill_zero_size :
    (reservedValueFill true ByteArray.empty).size = 32 := by
  rw [reservedValueFill_fill true ByteArray.empty rfl rfl]
  exact zeroBytes_size 32

/-! ## BLK-127 — memoization-only cache flags -/

@[rule "BLK-127"]
theorem memoVerdict_hit (b fresh : Bool) : memoVerdict (some b) fresh = b := rfl

@[rule "BLK-127"]
theorem memoVerdict_miss_row (fresh : Bool) : memoVerdict none fresh = fresh := rfl

end BitcoinProofs.AF.PDW39
