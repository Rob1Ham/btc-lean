# Cell `checksig/C-L-checksig-pubkey-encoding`

## What is proved

Three closed functions per leg, over symbolic `hdr` (i8), `len`, both policy
bits, `sv`, `sig_len`, `crypto_ok` and `null_fail`:

| Function | Observable |
|---|---|
| `cell_pubkey_encoding` | Core `CheckPubKeyEncoding` pass / 29 / 44 |
| `cell_pubkey_encoding_checksig` | full checksig path + EVAL_FALSE tail |
| `cell_pubkey_encoding_continue` | same path + one `OP_NOT` |

Alive2 proves C ≡ L bidirectionally on the extracted IR; SAW proves each leg
against the independent Cryptol restatement in `saw/pk_encoding.cry`.

Block-mode invalid key (`hdr=0x02, len=1`, policy bits 0): `CPubKey::ValidSize`
false → `CheckECDSASignature` false → push false (264), or 10497 after
`OP_NOT`.  Policy STRICTENC on the same key: `PUBKEYTYPE` 29 abort.  v0
WITNESS_PUBKEYTYPE on a 65-byte uncompressed key: 44 abort.  NULLFAIL with a
non-empty signature: 32 abort.

## Why partial (and why the row must stay `gap`)

The L leg uses `validPubKeySize` (the size-exact port already present at
`Bitcoin/Crypto/EcdsaDeep/PubKeyParse.lean:135-136`), **not** the pinned
`Bitcoin/Crypto/Seam/Der.isValidPubKey` (`Der.lean:175`), which is header-only
and is F-DIV-004.  The pinned `Seam/Entry.ecdsaVerdict` gate therefore does
not compute the predicate proved here.  The cell demonstrates that the
corrected gate is behavior-preserving against Core and gives the exact
coverage a post-fix cell would carry; it does not certify the current model.
The divergence is shown live by
`findings/wave65/13-scr-112/probe/` (header-only L leg, same C slice).

The payload bytes after the header are not inputs because no predicate in the
slice reads them.  That is a domain reduction stated in `spec.md`, not an
abstraction of the rule.

## Tooling notes

- Alive2: `-O1` both legs, `llvm-extract --recursive`, `--bidirectional`.
  The runner strips attached TBAA/alias.scope/noalias/nonnull metadata
  identically from both legs; Alive2 v20 rejects those hints in some shapes
  and they carry no semantics.  This cell's pure scalar functions do not
  generate such metadata in practice, but the strip is retained for parity
  with the wave-16 runner.
- SAW: `-O0` both legs, no stubs (no external calls).
- There is no R leg (F-HARNESS-002 / F-TOOL-001).

## What is *not* claimed

- No EC verification, point validation, or sighash.
- No DER/LOW_S/hashtype check; the signature is assumed encoding-valid.
- No full block replay.
