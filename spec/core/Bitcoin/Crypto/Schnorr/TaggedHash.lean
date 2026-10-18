import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Crypto.Ecdsa.Verify

/-!
# Bitcoin.Crypto.Schnorr.TaggedHash — BIP340/BIP341 tagged hashes (the Schnorr module)

`tagged_hash(tag, msg) = SHA256(SHA256(tag) ‖ SHA256(tag) ‖ msg)`
(BIP340 §design: "domain separation via tagged hashes"; BIP341 §hash
computation reuses the same construction for TapTweak/TapLeaf/TapSighash).

Built ON the existing core SHA-256 (`Bitcoin.Crypto.Seam.Hash.sha256`,
the vendored prototype — proved `sha256_size : … = 32` and verified
18/18 digests against python hashlib; the Schnorr module does NOT reimplement it).

The 32-byte integer encodings fed into the challenge hash reuse
`Ecdsa.Verify.beBytes32` (big-endian, `secp256k1_eckey_pubkey_serialize`
payload convention) — BIP340 writes all integers in these hashes as
fixed-width big-endian (`bytes(x)`, §design §"Specification").
-/

namespace Bitcoin.Crypto.Schnorr

open Bitcoin.Crypto.Seam.Hash (sha256_size)
open Bitcoin.Crypto.Seam.Hash.Sha256 (sha256)

/-- BIP340/BIP341 tagged hash (bip-0340.mediawiki §design; identical
construction in bip-0341 §3 hash computations):
`SHA256(SHA256(tag) ‖ SHA256(tag) ‖ msg)`. -/
def taggedHash (tag msg : ByteArray) : ByteArray :=
  sha256 (sha256 tag ++ sha256 tag ++ msg)

/-! ## The five tags the consensus layers need -/

/-- BIP340 verification challenge tag (bip-0340 §"Verification", step 5). -/
def tagBip0340Challenge : ByteArray := "BIP0340/challenge".toUTF8

/-- BIP340 signing nonce tag (bip-0340 §"Alternative Signing"; listed for
completeness — verification itself never uses it). -/
def tagBip0340Nonce : ByteArray := "BIP0340/nonce".toUTF8

/-- BIP341 output-key tweak tag (bip-0341 §3: `t = hashTapTweak(…)`) —
the Taproot module's entry point into this module. -/
def tagTapTweak : ByteArray := "TapTweak".toUTF8

/-- BIP341 tapscript-leaf tag (bip-0341 §3: `hashTapLeaf(…)`) — the Taproot and interpreter delta layers. -/
def tagTapLeaf : ByteArray := "TapLeaf".toUTF8

/-- BIP342 signature-message tag (bip-341 §3: `hashTapSighash(…)`) —
the sighash lane the Taproot and interpreter delta layers own. -/
def tagTapSighash : ByteArray := "TapSighash".toUTF8

/-! ## The BIP340 challenge: e's preimage -/

/-- The challenge preimage `bytes(r) ‖ bytes(P.x) ‖ m` (BIP340 §"Verification",
step 5) — all three pieces 32 bytes big-endian. -/
def challengePre (r px : Nat) (msg : ByteArray) : ByteArray :=
  Bitcoin.Crypto.Ecdsa.Verify.beBytes32 r
    ++ Bitcoin.Crypto.Ecdsa.Verify.beBytes32 px ++ msg

/-- `e`'s digest BEFORE the mod-n reduction: `t = tagged_hash("BIP0340/challenge",
bytes(r) ‖ bytes(P.x) ‖ m)` (bip-0340 step 5); the verifier reduces mod `n`. -/
def challengeTagged (r px : Nat) (msg : ByteArray) : ByteArray :=
  taggedHash tagBip0340Challenge (challengePre r px msg)

/-! ## Size contracts (mirror the seam layer's `sha256_size` discipline, B5) -/

/-- Concatenation size: `ByteArray` append is elementwise. -/
theorem append_size (a b : ByteArray) : (a ++ b).size = a.size + b.size := by
  have h : (a ++ b).data.toList = a.data.toList ++ b.data.toList := rfl
  have h1 : a.size = a.data.toList.length := rfl
  have h2 : b.size = b.data.toList.length := rfl
  have h3 : (a ++ b).size = (a ++ b).data.toList.length := rfl
  rw [h3, h, h1, h2, List.length_append]

/-- The tagged hash is a 32-byte digest (composition of `sha256_size`). -/
theorem taggedHash_size (tag msg : ByteArray) : (taggedHash tag msg).size = 32 := by
  unfold taggedHash
  simp only [sha256_size]

/-- `beBytes32` is exactly 32 bytes (structural: `(Array.range 32).map …`). -/
theorem beBytes32_size (x : Nat) :
    (Bitcoin.Crypto.Ecdsa.Verify.beBytes32 x).size = 32 := by
  unfold Bitcoin.Crypto.Ecdsa.Verify.beBytes32 ByteArray.size
  simp only [Array.size_map, Array.size_range]

/-- The challenge preimage is exactly 64 + msg.size bytes: 32 + 32 + msg. -/
theorem challengePre_size (r px : Nat) (msg : ByteArray) :
    (challengePre r px msg).size = 64 + msg.size := by
  unfold challengePre
  rw [append_size, append_size, beBytes32_size, beBytes32_size]

/-- The challenge digest is 32 bytes. -/
theorem challengeTagged_size (r px : Nat) (msg : ByteArray) :
    (challengeTagged r px msg).size = 32 := taggedHash_size _ _

end Bitcoin.Crypto.Schnorr
