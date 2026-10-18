import Bitcoin.Capstone.Pow

/-!
# BitcoinProofs.Theorems.CapstonePowCor — P05: proved PoW-layer spec (sorry-free)

Corollaries and exact-value pins over the executable capstone PoW layer
(`Bitcoin.Capstone.Pow`, core `spec/core/Bitcoin/Capstone/Pow.lean`) and the
compact-bits decoder (`Bitcoin.Chain.compactTarget`, core
`spec/core/Bitcoin/Chain/Basic.lean`). These turn the runtime booleans that
`lake exe capstone` adjudicates on real mainnet anchors (BLK-037/038/039)
into proved statements.

C4 portfolio linkage:

| C4 ID        | theorem here              | statement (short) |
|--------------|---------------------------|-------------------|
| (BLK-003 cor) | `hashNatLE_empty`        | LE-interpretation of the empty digest is 0 |
| (BLK-003 cor) | `hashNatLE_zero_prefix`  | LE-interpretation of 32 zero bytes is 0 (leading-zero high-hash form) |
| (BLK-003 cor) | `hashNatLE_le_byte_bound`| `hashNatLE b < 256 ^ b.size` — a 32-byte digest is always a < 2^256 integer (bytes are ≤ 255 by construction of `UInt8`, so no hypothesis is needed) |
| (BLK-037+038) | `compactTarget_genesis`  | exact decoded difficulty-one target, with a separate strict bound below the full mainnet limit |
| (BLK-037+038) | `targetOk_genesis`       | the REAL mainnet genesis/early-anchor nBits `0x1d00ffff` passes the decode gate |
| (BLK-039)     | `powOk_iff_conj`         | `powOk h = true` ⟺ target gate holds ∧ LE-integer of the header hash ≤ target (Bool-and characterization of the "high-hash" adjudication) |
| (BLK-038 cor) | `targetOk_pos_of_ok` / `targetOk_le_powLimit_of_ok` | a passing nBits decodes to a nonzero target ≤ `powLimit` (the `fNegative ‖ fOverflow ‖ target == 0 ‖ target > powLimit` reject arms of Core `CheckProofOfWork`, pow.cpp:95-116) |

Dependencies: core only — `Bitcoin.Chain.compactTarget_difficulty_one` (rfl),
`Bitcoin.Capstone.Pow.{headerHash,hashNatLE,powLimit,targetOk,powOk}`.
No Mathlib. Every theorem is sorry-free; axiom footprints are recorded per theorem below.
-/

namespace BitcoinProofs.Theorems.CapstonePow

open Bitcoin.Chain Bitcoin.Capstone.Pow

/-! ## `hashNatLE`: little-endian byte-string interpretation (BLK-003) -/

/-- Worker lemma for `hashNatLE_le_byte_bound`: the partial LE-interpretation
over the first `n` index positions is always `< 256 ^ n`. The bound does not
need `n ≤ b.size`: `ByteArray.get!` reads at most `255` for an in-bounds byte
(`UInt8.toNat_lt_size`) and `0` out of bounds. -/
theorem hashNatLE_foldl_lt (b : ByteArray) :
    ∀ n : Nat, (List.range n).foldl (fun acc i => acc + (b.get! i).toNat * 256 ^ i) 0
      < 256 ^ n := by
  intro n
  induction n with
  | zero => simp
  | succ n ih =>
    rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    have hbyte : (b.get! n).toNat ≤ 255 := Nat.le_of_lt_succ (b.get! n).toNat_lt_size
    have hpow : 256 ^ (n + 1) = 256 ^ n * 256 := by rw [Nat.pow_succ]
    calc (List.range n).foldl (fun acc i => acc + (b.get! i).toNat * 256 ^ i) 0
          + (b.get! n).toNat * 256 ^ n
        ≤ 255 * 256 ^ n
          + (List.range n).foldl (fun acc i => acc + (b.get! i).toNat * 256 ^ i) 0 := by
          rw [Nat.add_comm]
          exact Nat.add_le_add_right
            (Nat.mul_le_mul_right _ hbyte)
            ((List.range n).foldl (fun acc i => acc + (b.get! i).toNat * 256 ^ i) 0)
      _ < 255 * 256 ^ n + 256 ^ n := Nat.add_lt_add_left ih _
      _ = 256 ^ (n + 1) := by rw [hpow]; omega

/-- The LE-interpretation of the empty byte string is 0
(axiom footprint: none). -/
theorem hashNatLE_empty : hashNatLE ByteArray.empty = 0 := rfl

/-- The LE-interpretation of 32 zero bytes is 0: a digest of all-zero bytes
(the degenerate "leading-zero" form) contributes nothing to `powOk`'s
comparison (axiom footprint: none). -/
theorem hashNatLE_zero_prefix :
    hashNatLE (ByteArray.mk (Array.replicate 32 (0 : UInt8))) = 0 := by decide

/-- A byte string interpreted little-endian is strictly below `256` to the
number of bytes: `hashNatLE` of a 32-byte SHA256d digest is always a genuine
`< 2^256` natural. Each byte is `≤ 255` by construction (`UInt8.toNat_lt_size`),
so the statement needs no hypothesis (axiom footprint: [propext, Quot.sound],
inherited from the core `List.range_succ`/`List.foldl_append` simp lemmas). -/
theorem hashNatLE_le_byte_bound (b : ByteArray) :
    hashNatLE b < 256 ^ b.size :=
  hashNatLE_foldl_lt b b.size

/-! ## The difficulty-one target and full mainnet limit (BLK-037+BLK-038) -/

/-- Exact decoded difficulty-one target. Core's full powLimit is larger. -/
theorem compactTarget_genesis :
    compactTarget 0x1d00ffff = 0xffff * 256 ^ 26 := rfl

/-- The decoded difficulty-one target is strictly below the full live limit. -/
theorem compactTarget_genesis_lt_limit : compactTarget 0x1d00ffff < powLimit :=
  Bitcoin.Block.Pow.difficultyOne_lt_powLimitMainnet

/-- The REAL mainnet genesis / early-anchor nBits `0x1d00ffff` passes the
`CheckProofOfWork` decode gate (BLK-037+BLK-038): nonzero target, ≤ powLimit
(axiom footprint: [propext, Quot.sound]). -/
theorem targetOk_genesis : targetOk 0x1d00ffff = true := rfl

/-! ## `powOk`: the high-hash adjudication (BLK-039) -/

/-- `powOk h = true` unfolds to the exact conjunction the capstone adjudicates:
the target gate passes AND the header hash, read little-endian, is `≤` the
target (axiom footprint: [propext, Quot.sound]). -/
@[rule "BLK-039"]
theorem powOk_iff_conj (h : BlockHeader) :
    powOk h = true ↔
      targetOk h.bits = true ∧
      hashNatLE (headerHash h) ≤ compactTarget h.bits := by
  simp [powOk, Bool.and_eq_true]

/-- A passing nBits decodes to a POSITIVE target — the `target == 0` reject
arm of Core `CheckProofOfWork` (pow.cpp:95-116) never fires for a block that
reaches the hash comparison (axiom footprint: [propext, Quot.sound]). -/
theorem targetOk_pos_of_ok (bits : UInt32) (h : targetOk bits = true) :
    0 < compactTarget bits := by
  simp only [targetOk, Bool.and_eq_true, decide_eq_true_iff] at h
  exact h.1.2

/-- A passing nBits decodes to a target `≤ powLimit` — the
`target > powLimit` reject arm of Core `CheckProofOfWork` never fires for a
block that reaches the hash comparison (axiom footprint: [propext,
Quot.sound]). -/
theorem targetOk_le_powLimit_of_ok (bits : UInt32) (h : targetOk bits = true) :
    compactTarget bits ≤ powLimit := by
  simp only [targetOk, Bool.and_eq_true, decide_eq_true_iff] at h
  exact h.2

end BitcoinProofs.Theorems.CapstonePow

-- R07c exact footprint guards.
/-- info: 'BitcoinProofs.Theorems.CapstonePow.compactTarget_genesis_lt_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstonePow.compactTarget_genesis_lt_limit
