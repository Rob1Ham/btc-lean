import Bitcoin.Crypto.Taproot.OutputKey
import Bitcoin.Crypto.Taproot.Tree
import Bitcoin.Crypto.Taproot.Sighash

/-! # PDW35.lean — proof-promotion review RC27, items TOP-171..175
(PDW35, 2026-10-17). Claim 6698452.

Taproot-commitment tail (D-TPROUT/D-TPRTREE) + the TPR-030 sighash
hashtype gate. Route B: tagged restatements of sorry-free in-tree
polarity theorems; zero core writes.

* TPR-011 `parityOk` — control[0] parity gate (interpreter.cpp:1924).
* TPR-013 `tapBranch` — sorted-pair TapBranch commitment (BIP341:75-76).
* TPR-014 `taprootMerkleRoot` — control-block Merkle walk (BIP341:74).
* TPR-018 `internalKeyOk` — control pubkey lift_x parse (pubkey.cpp:260).
* TPR-030 `hashtypeValid` — hash_type gate (interpreter.cpp:1532).
-/

namespace BitcoinProofs.AF.PDW35

open Bitcoin.Crypto.Schnorr (taggedHash)
open Bitcoin.Crypto.Taproot
open Bitcoin.Crypto.Taproot.OutputKey (parityOk internalKeyOk)

/-! ## TPR-011 — control-block parity -/

/-- TPR-011 row face: a well-formed control block passes iff its low
parity bit equals `y(Q) mod 2`; the empty block fails closed. -/
@[rule "TPR-011"]
theorem parityOk_row (control : ByteArray) (yQ : Nat) :
    parityOk control yQ = true ↔
      0 < control.size ∧ (control.get! 0).toNat % 2 = yQ % 2 := by
  unfold parityOk
  by_cases h : 0 < control.size
  · simp [h]
  · simp [h]

/-- TPR-011 reject lane: the empty control block never passes. -/
theorem parityOk_empty_row (yQ : Nat) :
    parityOk ByteArray.empty yQ = false := by
  unfold parityOk; rfl

/-- TPR-011 discrimination: an even control byte accepts exactly even
`y(Q)` (flipping the parity bit flips the accept set). -/
theorem parityOk_flip_row (b : ByteArray) (yQ : Nat) (h : 0 < b.size)
    (hp : (b.get! 0).toNat % 2 = 0) :
    parityOk b yQ = true ↔ yQ % 2 = 0 := by
  rw [Bitcoin.Crypto.Taproot.OutputKey.parityOk_eq b yQ h, hp, beq_iff_eq]
  exact eq_comm

/-! ## TPR-018 — internal-key parse -/

/-- TPR-018 row face: for a size-gated control block, the check is
exactly `liftX` on the big-endian parse of bytes 1..33. -/
@[rule "TPR-018"]
theorem internalKeyOk_row (control : ByteArray) (h : 33 ≤ control.size) :
    internalKeyOk control =
      (Bitcoin.Crypto.Curve.Secp.liftX
        (Bitcoin.Crypto.Curve.Secp.bytesToNatBE
          (control.extract 1 33))).isSome :=
  Bitcoin.Crypto.Taproot.OutputKey.internalKeyOk_eq control h

/-- TPR-018 reject lane: `x ≥ p` does not lift, so the check fails. -/
theorem internalKeyOk_geP_row (control : ByteArray) (h : 33 ≤ control.size)
    (hx : Bitcoin.Crypto.Curve.Secp.P ≤
      Bitcoin.Crypto.Curve.Secp.bytesToNatBE (control.extract 1 33)) :
    internalKeyOk control = false :=
  Bitcoin.Crypto.Taproot.OutputKey.internalKeyOk_geP control h hx

/-! ## TPR-013 — sorted-pair TapBranch -/

/-- TPR-013 row face: the branch pairing is order-independent, hashes
`a ‖ a` on the diagonal, and always yields a 32-byte digest. -/
@[rule "TPR-013"]
theorem tapBranch_row (a b : ByteArray) :
    tapBranch a b = tapBranch b a ∧
    tapBranch a a = taggedHash tagTapBranch (a ++ a) ∧
    (tapBranch a b).size = 32 :=
  ⟨tapBranch_comm a b, tapBranch_diag a, tapBranch_size a b⟩

/-! ## TPR-014 — control-block Merkle walk -/

/-- TPR-014 row face: the empty path returns the tapleaf hash, the
cons step is `tapBranch k e`, and a one-node path is one TapBranch
(BIP341:74). -/
@[rule "TPR-014"]
theorem taprootMerkleRoot_row (e : ByteArray) (rest : List ByteArray)
    (tl : ByteArray) :
    taprootMerkleRoot [] tl = tl ∧
    taprootMerkleRoot (e :: rest) tl = taprootMerkleRoot rest (tapBranch tl e) ∧
    taprootMerkleRoot [e] tl = tapBranch tl e :=
  ⟨rfl, rfl, rfl⟩

/-- TPR-014 boundary: the empty path returns the tapleaf hash. -/
theorem taprootMerkleRoot_nil_row (tl : ByteArray) :
    taprootMerkleRoot [] tl = tl := rfl

/-- TPR-014 boundary: a one-node path is a single TapBranch. -/
theorem taprootMerkleRoot_single_row (e tl : ByteArray) :
    taprootMerkleRoot [e] tl = tapBranch tl e := by rfl

/-! ## TPR-030 — hash_type gate -/

/-- TPR-030 row face: the gate accepts exactly `ht ≤ 3` or
`0x81 ≤ ht ≤ 0x83` (SIGHASH_DEFAULT/ALL/NONE/SINGLE and the three
ANYONECANPAY forms). -/
@[rule "TPR-030"]
theorem hashtypeValid_row (ht : UInt8) :
    hashtypeValid ht = true ↔
      ht.toNat ≤ 3 ∨ (0x81 ≤ ht.toNat ∧ ht.toNat ≤ 0x83) := by
  unfold hashtypeValid
  simp [Bool.or_eq_true, decide_eq_true_eq]

/-- TPR-030 reject lanes: the gap byte `0x80` and the out-of-range
bytes `0x04`/`0x84` fail the gate. -/
theorem hashtypeValid_rejects :
    hashtypeValid 0x04 = false ∧
    hashtypeValid 0x80 = false ∧
    hashtypeValid 0x84 = false := by decide

end BitcoinProofs.AF.PDW35
