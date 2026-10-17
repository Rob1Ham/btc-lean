import Bitcoin.Data.Basic
import Bitcoin.Crypto.Schnorr.Verify

/-!
# Bitcoin.Crypto.Schnorr — FROZEN INTERFACE STUB (W01)

Owning workstream     : W14 (2B slot) / Review 3 (proofs)
Dependent workstreams : W13 (seam: `checkSchnorrSignature` implementation)
Core counterpart files: src/crypto/secp256k1 (schnorr_impl.h), BIP340
Status                : frozen 2026-10-16 by W01 — MINIMAL STUB.
                        BIP340 formal verification is a documented VOID
                        (A3/A4: no Lean 4 secp256k1 exists anywhere) —
                        this is the project's differentiator, Review 3.

FILL HISTORY (X02): the `opaque ... := sorry` placeholder below was
replaced by a real implementation routing to
`Bitcoin.Crypto.Schnorr.Verify.verifyImpl` (BIP340 over the W14b raw
`Nat` curve layer; 19/19 official vectors incl. negatives, see
`spec/Test/Crypto/SchnorrTest.lean`), signature byte-identical. The
`opaque` wrapper is kept deliberately: the consensus surface stays the
frozen constant, and `#print axioms` on downstream theorems pins against
the interface, not the implementation.
-/

namespace Bitcoin.Crypto.Schnorr

/-- BIP340 Schnorr verification over the 32-byte-key encoding.
Review 3 (X02): real verification over the W14/W14b curve+field layer.
Arg order `(sig, pk, msg)` — mirrors the W13 seam call `schnorrVerdict`
makes (`verify body pk h`). -/
-- FILL[X02]: was SORRY[W01] stub; body = BIP340 verifyImpl over Curve.Secp.
opaque verifyBip340 : ByteArray → ByteArray → ByteArray → Bool :=
  Verify.verifyImpl

end Bitcoin.Crypto.Schnorr
