import Bitcoin.Data.Basic
import Bitcoin.Crypto.Schnorr.Verify

/-!
# Bitcoin.Crypto.Schnorr — FROZEN INTERFACE STUB

Core counterpart files: src/crypto/secp256k1 (schnorr_impl.h), BIP340
Status: frozen 2026-10-16 — MINIMAL STUB.
                        BIP340 formal verification is a documented VOID
                        (the real-verifier criterion: no Lean 4 secp256k1 exists anywhere) —
                        this is the project's differentiator.

FILL HISTORY (the Schnorr module): the `opaque ... := sorry` placeholder below was
replaced by a real implementation routing to
`Bitcoin.Crypto.Schnorr.Verify.verifyImpl` (BIP340 over the raw
`Nat` curve layer; 19/19 official vectors incl. negatives, see
`spec/Test/Crypto/SchnorrTest.lean`), signature byte-identical. The
`opaque` wrapper is kept deliberately: the consensus surface stays the
frozen constant, and `#print axioms` on downstream theorems pins against
the interface, not the implementation.
-/

namespace Bitcoin.Crypto.Schnorr

/-- BIP340 Schnorr verification over the 32-byte-key encoding.
(the Schnorr module): real verification over the curve and field layers.
Arg order `(sig, pk, msg)` — mirrors the seam call `schnorrVerdict`
makes (`verify body pk h`). -/
-- FILL (the Schnorr module): was SORRY stub; body = BIP340 verifyImpl over Curve.Secp.
opaque verifyBip340 : ByteArray → ByteArray → ByteArray → Bool :=
  Verify.verifyImpl

end Bitcoin.Crypto.Schnorr
