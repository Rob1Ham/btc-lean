import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Crypto.Taproot.Sighash

/-! # PDW41/TPR006.lean — TPR-006 row face (BIP341 sha_annex)

Claim v2 `d87a0cb`. Route B, zero core writes.

TPR-006: `sha_annex = SHA256(CompactSize(len) ‖ annex)` where the annex
INCLUDES its mandatory 0x50 tag byte (interpreter.cpp:1964 + 1554-1556,
`execdata.m_annex_hash`). Row faces: preimage pin, 32-byte digest, the
0x50 tag inclusion, and cross-layer agreement with the sighash module's
`shaAnnex` (one annex hash, two defs). -/

namespace BitcoinProofs.AF.PDW41

open Bitcoin.Crypto.Taproot.Program
open Bitcoin.Data (compactSizeEnc serU8)

/-- TPR-006 (preimage pin): CompactSize(length) then the annex bytes,
single SHA256 — no double hash, no trailing data. -/
@[rule "TPR-006"]
theorem annexHash_row (annex : ByteArray) :
    annexHash annex = Bitcoin.Crypto.Seam.Hash.Sha256.sha256
      (compactSizeEnc annex.size ++ annex) := rfl

/-- TPR-006 (digest width): sha_annex is 32 bytes (safe as a sighash
field, which Core types as `uint256`). -/
theorem annexHash_size32 (annex : ByteArray) : (annexHash annex).size = 32 := by
  unfold annexHash
  exact Bitcoin.Crypto.Seam.Hash.sha256_size _

/-- TPR-006 (0x50 tag included): the mandatory annex tag byte is inside
the hashed preimage, so annexes differing only in the tag diverge. -/
theorem annexHash_tag_included (rest : ByteArray) :
    annexHash (serU8 0x50 ++ rest) =
      Bitcoin.Crypto.Seam.Hash.Sha256.sha256
        (compactSizeEnc (serU8 0x50 ++ rest).size ++ (serU8 0x50 ++ rest)) :=
  annexHash_row _

/-- TPR-006 (cross-layer): the Program-layer `annexHash` and the
sighash-layer `shaAnnex` are the SAME function — the annex commitment
cannot drift between the recognition and sighash lanes. -/
theorem annexHash_eq_shaAnnex (annex : ByteArray) :
    annexHash annex = Bitcoin.Crypto.Taproot.shaAnnex annex := rfl

end BitcoinProofs.AF.PDW41
