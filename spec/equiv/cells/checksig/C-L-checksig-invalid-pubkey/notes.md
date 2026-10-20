# Cell `checksig/C-L-checksig-invalid-pubkey`

## What is proved

Two closed functions per leg over symbolic `pk_valid`, `crypto_ok`, `sig_len`
and `nullFail`:

| Function | Result |
|---|---|
| `cell_invalid_pubkey` | CHECKSIG push (no continuation op) |
| `cell_invalid_pubkey_continue` | CHECKSIG then OP_NOT (block continues) |

The checker is `pk_valid ? crypto_ok : 0`.  For an invalid key the result is
false for *every* `crypto_ok`, because pinned Core returns false on
`!pubkey.IsValid()` before the EC call.  With NULLFAIL off a non-empty
signature pushes false (`264`) or, through OP_NOT, a true final stack
(`10497`); a passing check pushes true (`10497`) or, through OP_NOT, the
false element retained on top (`2312`).  With NULLFAIL on and a non-empty
signature, the failed check returns `128` (error 32) before the push.

## Why partial

- `CPubKey::IsValid()` / `CPubKey::Set` is taken as an input, not computed
  from the pubkey bytes; the byte-level structural parse is not modelled.
- The valid-key branch uses the abstract EC verdict (`crypto_ok`), i.e. the
  same-crypto premise of `docs/DECISION-lax-ecdsa.md`.  The invalid-key
  implication itself does not depend on it.
- No R leg (F-HARNESS-002 / F-TOOL-001).
- The existing ledger anchor `e3-checksig/C-L-checksig-dispatch` is outside
  this task's write scope and was not edited; this cell supplements it.

## Observable note

`st_finish` keeps the stack on an EVAL_FALSE result, so OP_NOT on a true
value yields `2312` (depth 1, length 1, value 0), not `264` (empty top).
The first SAW attempt used `264` and was rejected; the Cryptol predicate now
carries the retained element.  This is an observable, not a semantic,
difference and both legs always agreed with each other.

## What is *not* claimed

- No byte-level pubkey parse, no EC point validation, no sighash.
- No DER/LOW_S/STRICTENC gates; the cell starts at the checker boundary.
- Alive2 v20 TBAA/alias.scope strip applies identically to both legs.
