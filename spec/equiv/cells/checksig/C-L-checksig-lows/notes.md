# Cell `checksig/C-L-checksig-lows`

## What is proved

One closed function per leg, `cell_lows_gate(lowS, s0..s3)`: with LOW_S off
it returns 0; with LOW_S on it returns 0 iff the 256-bit S scalar is
`<= floor(n/2)`, else `SIG_HIGH_S = 27` (Core `IsLowDERSignature` →
`CPubKey::CheckLowS` → `secp256k1_ecdsa_signature_normalize`).  The threshold
is `0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0`,
compared most-significant limb first over fully symbolic limbs.

## Why partial

The cell assumes the canonical-scalar domain `s < n` (the signature already
passed strict BIP66 DER and the compact parser did not hit its overflow
window).  It does **not** model how S is extracted from the DER blob, nor the
`ecdsa_signature_parse_der_lax` `s >= n` overflow/reduction window (the
SGN-107 seam of `docs/DECISION-lax-ecdsa.md`).  SCR-104 therefore stays
partial.

## What is *not* claimed

- No DER parsing, no ECDSA verification, no sighash.
- No R leg (F-HARNESS-002 / F-TOOL-001).
- Alive2 v20 cannot ingest attached TBAA/alias.scope metadata in this shape,
  so the runner strips those optimizer hints from both legs identically.
