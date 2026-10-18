import Bitcoin.Data.Basic
import Bitcoin.Crypto.Ecdsa.Verify

/-!
# Bitcoin.Crypto.Ecdsa — INTERFACE (frozen interface, filled)

Core counterpart files: src/crypto/secp256k1 (ecdsa_impl.h — LAX
                        semantics: DER parse errors and high-S are
                        handled by the INTERPRETER (BIP66), the EC math
                        here is the lax verifier)
Status: filled 2026-10-16 — `verifyLax` now has a
                        real body (Core `CPubKey::Verify` semantics @
                        `cce32b168`); the `opaque` wrapper is kept so the
                        frozen interface signature is byte-identical.
-/

namespace Bitcoin.Crypto.Ecdsa

/-- ECDSA verification, **lax** semantics exactly as secp256k1's
`secp256k1_ecdsa_verify` (the DER/low-S/strict-enc layers live in the
interpreter, not here — the seam-design notes).

Argument order (the stub was unnamed):
`verifyLax sig pubKey msg32` — `sig` is the DER signature (trailing
sighash byte tolerated, parser stops early), `pubKey` is the 33-byte
compressed / 65-byte uncompressed-or-hybrid encoding, `msg32` is the
32-byte sighash. The seam must pass arguments in this order. -/
opaque verifyLax : ByteArray → ByteArray → ByteArray → Bool :=
  Verify.verifyImpl

end Bitcoin.Crypto.Ecdsa
