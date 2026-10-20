# Cell `checksig/C-L-checksig-policy`

## What is proved

Four closed functions per leg over symbolic lengths, prefix bytes, policy
bits and SigVersion:

| Function | Rule | Result |
|---|---|---|
| `cell_is_defined_hashtype` | `n > 0 && (last & 0x7f) ∈ {1,2,3}` | 0/1 |
| `cell_hashtype_gate` | STRICTENC hashtype arm | 0 or 23 |
| `cell_pubkey_predicates` | `IsCompressedOrUncompressedPubKey`, `IsCompressedPubKey` | packed bits |
| `cell_pubkey_encoding` | `CheckPubKeyEncoding` | 0, 29 or 44 |

`last` is the final signature byte (masked to 0..255 exactly as Core's
`unsigned char`); `n` is the signature length for the hashtype rule and the
pubkey length for the encoding rules.  The two pubkey predicates are purely
structural (size and prefix byte), so the cell carries no same-crypto
premise.  STRICTENC is checked before WITNESS_PUBKEYTYPE; the latter applies
only at `SigVersion::WITNESS_V0` (sv = 1).  Error ordinals are Core's
(23/29/44).

## What is *not* claimed

- Whether a well-encoded key is a valid curve point is the checker's
  business (SCR-112), not this cell.
- No LOW_S (separate cell `C-L-checksig-lows`) and no empty-signature bypass
  (DER cell `cell_der_gate`).
- No R leg (F-HARNESS-002 / F-TOOL-001).
- Alive2 v20 cannot ingest attached TBAA/alias.scope metadata in this shape,
  so the runner strips those optimizer hints from both legs identically.
