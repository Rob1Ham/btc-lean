import Bitcoin.Crypto.Taproot.Tree

/-! # PDW41/TPR012.lean — TPR-012 row face (TapLeaf hash)

Claim v2 `d87a0cb`. Route B, zero core writes.

TPR-012: `tapLeaf v s = tag_TapLeaf(serU8 v ‖ CSize(s.size) ‖ s)`
(interpreter.cpp:1882-1885 `ComputeTapleafHash`; BIP341). Row faces:
preimage pin, 32-byte digest, and byte-determinism (congruence). -/

namespace BitcoinProofs.AF.PDW41

open Bitcoin.Crypto.Taproot
open Bitcoin.Data (compactSizeEnc serU8)

/-- TPR-012 (preimage pin): leaf version byte, CompactSize script
length, then the script — exactly Core's HashWriter sequence. -/
@[rule "TPR-012"]
theorem tapLeaf_row (v : UInt8) (script : ByteArray) :
    tapLeaf v script = Bitcoin.Crypto.Schnorr.taggedHash Bitcoin.Crypto.Schnorr.tagTapLeaf
      (serU8 v ++ compactSizeEnc script.size ++ script) := rfl

/-- TPR-012 (digest width): a tapleaf hash is 32 bytes — the leaf node
of the BIP341 Merkle tree. -/
theorem tapLeaf_size32 (v : UInt8) (script : ByteArray) :
    (tapLeaf v script).size = 32 := by
  unfold tapLeaf
  exact Bitcoin.Crypto.Schnorr.taggedHash_size _ _

/-- TPR-012 (determinism): equal (version, script) inputs give equal
leaf hashes — the commitment is a function of the leaf only. -/
theorem tapLeaf_congr (v₁ v₂ : UInt8) (s₁ s₂ : ByteArray)
    (hv : v₁ = v₂) (hs : s₁ = s₂) : tapLeaf v₁ s₁ = tapLeaf v₂ s₂ := by
  rw [hv, hs]

end BitcoinProofs.AF.PDW41
