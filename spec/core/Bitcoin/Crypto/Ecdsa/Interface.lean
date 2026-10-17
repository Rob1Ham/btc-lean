import Bitcoin.Data.Basic
import Bitcoin.Crypto.Ecdsa.Verify

/-!
# Bitcoin.Crypto.Ecdsa — INTERFACE (W01 freeze, W14b fill)

Owning workstream     : W14 (2B slot: ECDSA-lax verify)
Dependent workstreams : W13 (seam: `checkECDSASignature` implementation)
Core counterpart files: src/crypto/secp256k1 (ecdsa_impl.h — LAX
                        semantics: DER parse errors and high-S are
                        handled by the INTERPRETER (BIP66), the EC math
                        here is the lax verifier)
Status                : filled 2026-10-16 by W14b — `verifyLax` now has a
                        real body (Core `CPubKey::Verify` semantics @
                        `cce32b168`); the `opaque` wrapper is kept so the
                        frozen W01 interface signature is byte-identical.
-/

namespace Bitcoin.Crypto.Ecdsa

/-- ECDSA verification, **lax** semantics exactly as secp256k1's
`secp256k1_ecdsa_verify` (the DER/low-S/strict-enc layers live in the
interpreter, not here — B5/B2 findings).

Argument order (W14b pin, W01's stub was unnamed):
`verifyLax sig pubKey msg32` — `sig` is the DER signature (trailing
sighash byte tolerated, parser stops early), `pubKey` is the 33-byte
compressed / 65-byte uncompressed-or-hybrid encoding, `msg32` is the
32-byte sighash. W13's seam must pass arguments in this order. -/
opaque verifyLax : ByteArray → ByteArray → ByteArray → Bool :=
  Verify.verifyImpl

end Bitcoin.Crypto.Ecdsa
