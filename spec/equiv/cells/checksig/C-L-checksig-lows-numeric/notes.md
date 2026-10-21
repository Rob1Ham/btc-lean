# Cell `checksig/C-L-checksig-lows-numeric`

## What is proved

One closed function per leg, `cell_lows_numeric(lowS, s0..s3)`, over all
2^256 raw S magnitudes and both LOW_S values:

| lowS | raw S | result |
|---|---|---|
| 0 | any | 0 |
| 1 | `s >= n` | 0 (Core: parse_compact zeroes the pair; normalize sees 0) |
| 1 | `s < n`, `s <= n/2` | 0 |
| 1 | `s < n`, `s > n/2` | 27 `SIG_HIGH_S` |

Domain: the signature already passed BIP66, R is canonical (`r < n`) and no
stripped magnitude exceeds 32 bytes.  Under that premise the only overflow
source in `ecdsa_signature_parse_der_lax` is `s >= n`, which is exactly the
window this cell adds to the existing canonical-S cell.

- **C leg** (`src/c_leaf.cpp`): verbatim limb form of libsecp256k1
  `secp256k1_scalar_check_overflow` (scalar_4x64_impl.h:62-72) and
  `secp256k1_scalar_is_high` (:244-256), plus Core's parse_compact
  overflow-zeroing and the normalize disjunction.
- **L leg** (`src/l_leaf.cpp`): reviewed transliteration of
  `Der.isLowDERSignature`'s numeric half, `s % n <= n/2`, implemented as one
  conditional subtraction (n > 2^255) and a separate lexicographic 256-bit
  compare.  It is not the same code as the C leg.
- **SAW spec** (`src/cell.cry`): an independent mathematical predicate,
  `let red = if s >= n then s - n else s in red <= halfN`, applied to both
  modules.  It is not extracted from either leg.

## Commands actually run

From the repository root:

```sh
bash spec/equiv/cells/checksig/C-L-checksig-lows-numeric/alive2/run.sh
bash spec/equiv/cells/checksig/C-L-checksig-lows-numeric/saw/run.sh
sha256sum -c spec/equiv/cells/checksig/C-L-checksig-lows-numeric/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checksig/C-L-checksig-lows-numeric/saw/certificate.sha256
```

Observed terminal lines: `STATUS=alive2-green`, `STATUS=saw-green`.
Toolchain: clang/LLVM 20.1.2, Alive2 v20.0, SAW 1.6 (68eed5f), solver `abc`.

## What is not claimed

- No R value-overflow coupling: Core zeroes S when R >= n; Der.lean does not
  read R.  A canonical-R premise is required (see the filed seam).
- No DER byte parsing, no length-overflow window, no ECDSA, no sighash.
- No claim that `Defs.checkLowS` (raw S <= halfN) matches Core for S >= n;
  the runtime probe shows it does not.
- No R leg (F-HARNESS-002 / F-TOOL-001).
- Alive2 v20 cannot ingest attached TBAA/alias.scope metadata in this shape;
  the build strips those optimizer hints from both legs identically.  This is
  a tool-ingestion transform, recorded in `src/build.sh`.
- No shared files, ledger, matrix, or existing cell were edited.

## Mutant check

Removing the `scalar_check_overflow` arm from the C leg (the exact mutant named
in `spec.md`) leaves the L leg unchanged.  Alive2 then reports
`1 incorrect transformations` on the witness `s = n` (C returns 27, L returns
0), so the `s >= n` arm is load-bearing, not a tautology.  The mutation was
run in a scratch copy; the tracked sources are the unmutated ones.

## Seam evidence

`spec/equiv/findings/wave64/24-scr-104-low-s/` contains the exact pipeline
analysis, the three witness classes, a C probe linked against the pinned
libsecp256k1 source, and its raw output.  The probe confirms:

- `s = n`: Core `CheckLowS` = 1, `Der` = 1, `Defs` = 0.
- `r = n`, `s = n/2 + 1`: Core = 1, `Der` = 0, `Defs` = 0.
- 33-byte S (`lenS > 32`): Core = 1, `Der` = 1, `Defs` = 0.

All probe signatures are BIP66-valid (`bip66=1`), so each witness really
reaches `CPubKey::CheckLowS`.
