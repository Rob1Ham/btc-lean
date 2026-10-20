# Cell `checksig/C-L-checksig-der`

## What is proved

Two loop-free functions per leg, both over a fully symbolic 80-byte signature
buffer (`n` is a symbolic 32-bit length, `w0..w9` are ten symbolic 64-bit
words = 80 bytes):

| Function | Rule | Result |
|---|---|---|
| `cell_der` | `IsValidSignatureEncoding` / Lean `isDERSignature` | `1` iff strict BIP66 DER |
| `cell_der_gate` | `CheckSignatureEncoding` DERSIG arm + empty bypass | `0` or `SIG_DER = 24` |

Alive2 proves `C ≡ L` bidirectionally for every input in the domain
(`n ∈ [0,2^32)`, arbitrary 80-byte content), not on selected witnesses. SAW
proves each leg against the same independent Cryptol predicate
(`saw/der.cry`), so `C ⊨ spec` and `L ⊨ spec` hold over the same domain.

The whole rule is exercised: both size bounds (9 and 73), the compound tag,
the exact-length relation, the R/S tag bytes, zero-length integers, negative
bytes, and the minimal-padding clauses for both integers.  The empty-signature
bypass (`vchSig.size() == 0 → true`) is exercised by `cell_der_gate`.

## What is *not* claimed

- No ECDSA, DER-lax parser, or sighash behavior.  This cell is only the
  strict wire-encoding predicate; it never calls the checker.
- The signature is carried as an 80-byte word buffer instead of a
  `std::vector<unsigned char>`/`ByteArray`.  `sigbyte()` is the identical byte
  read; all length guards are kept in the source's order, so every read is in
  range exactly when the original read is.
- Alive2 v20 cannot ingest modules carrying attached TBAA/alias.scope
  metadata in this shape, so the runner strips those optimizer hints from both
  legs before comparison (same transform on both legs; recorded in notes.md).
- No R leg (F-HARNESS-002 / F-TOOL-001).
