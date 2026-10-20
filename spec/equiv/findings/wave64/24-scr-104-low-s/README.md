# wave64 / 24-scr-104 — LOW_S numeric seam

Contents:

- `SEAM.md` — exact Core/libsecp vs Lean `Der`/`Defs` LOW_S predicate
  analysis, difference sets, and the consequence for SCR-104.
- `probe_lows.c` — standalone probe using Core's verbatim
  `ecdsa_signature_parse_der_lax` and `IsValidSignatureEncoding`, linked
  against the pinned libsecp source.
- `probe_witnesses.txt` — raw probe output for ten BIP66-valid witnesses.

The proved cell is
`spec/equiv/cells/checksig/C-L-checksig-lows-numeric`: Core's
parse/normalize scalar predicate vs Lean `Der.isLowDERSignature` over the
whole 256-bit raw-S space, under canonical R and no length overflow.

This directory is evidence, not a cell and not a green claim.  SCR-104 stays
partial; the exact residual boundary is §2 of `SEAM.md`.
