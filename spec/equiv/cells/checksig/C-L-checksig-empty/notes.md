# Cell `checksig/C-L-checksig-empty`

## What is proved

Three closed functions per leg, over symbolic 32-bit policy/encoding inputs
(`pk_valid`, `strictEnc`, `witnessPubkeyType`, `sv`, `pk_len`, `pk0`):

| Function | Rule | Result |
|---|---|---|
| `cell_checksig_empty` | `OP_CHECKSIG` on an empty signature | pushes `vchFalse`; tail `EVAL_FALSE` |
| `cell_checksig_empty_continue` | same, then `OP_NOT` | execution continues, final top is true |
| `cell_checksigverify_empty` | `OP_CHECKSIGVERIFY` | ordinal 14 always |

Observables (ABI v2 packed word: result 2 | error 6 | depth 3 | top len 2 |
top value 8):

- pass + `OP_CHECKSIG`: `264` = result 0, `EVAL_FALSE` 2, depth 1, empty top;
- pass + `OP_NOT` continuation: `10497` = result 1, depth 1, top `{1}`;
- pass + `OP_CHECKSIGVERIFY`: `56` = result 0, error 14;
- pubkey-policy abort: `116` (`PUBKEYTYPE` 29) or `176`
  (`WITNESS_PUBKEYTYPE` 44).

Alive2 proves `C ≡ L` bidirectionally for every input in the domain. SAW
proves each leg against the same independent Cryptol predicate
(`saw/empty.cry`), so `C ⊨ spec` and `L ⊨ spec` hold over the same domain.

## Why no same-crypto premise

`CheckECDSASignature` (interpreter.cpp:1704-1720) returns false when
`!pubkey.IsValid()` and false when `vchSig.empty()`, both *before* sighash
construction or any ECDSA call.  `pubkey.IsValid()` is a structural length/
tag test, not EC math.  This cell therefore treats it as an unconstrained
boolean and the proofs show the observable is independent of it.  No
libsecp256k1, SHA-256, or ECDSA agreement is assumed.  (SCR-108's own
empty-signature *encoding* bypass over symbolic flags is proved separately in
`checksig/C-L-checksig-der`.)

## Source order kept

`CheckSignatureEncoding` (empty bypass) → `CheckPubKeyEncoding` (STRICTENC
arm, then the independent WITNESS_PUBKEYTYPE arm, which also runs when
STRICTENC accepted an uncompressed key) → checker → NULLFAIL guard (dead:
`sig.size == 0`) → `OP_CHECKSIG`/`OP_CHECKSIGVERIFY`.  The SAW predicate
initially collapsed the two policy arms into one `if/else`, which the prover
correctly rejected on `strictEnc=16, witnessPubkeyType=128, pk_len=65,
pk0=0x04`; the predicate now mirrors the source's two independent gates.

## What is *not* claimed

- `tail_not` is the cell's continuation witness for the following `OP_NOT`
  (interpreter.cpp:1073-1078), not part of `EvalChecksigPreTapscript`.
- No sighash, scriptCode, `FindAndDelete`, or transaction context: the empty
  signature makes them unobservable.
- No R leg (F-HARNESS-002 / F-TOOL-001).
- Alive2 v20 cannot ingest modules carrying attached TBAA/alias.scope
  metadata in this shape, so the runner strips those optimizer hints from both
  legs before comparison (same transform on both legs).
