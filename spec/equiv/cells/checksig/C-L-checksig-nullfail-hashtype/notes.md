# Cell `checksig/C-L-checksig-nullfail-hashtype`

## What is proved

Two closed functions per leg, over fully symbolic inputs:

| Function | Row | Inputs | Result |
|---|---|---|---|
| `cell_checksig_nullfail` | SCR-110 | `fSuccess`, `nullFail`, `sig_len`, `wire` | NULLFAIL 32, CHECKSIG push, or VERIFY 14 |
| `cell_hashtype` | SCR-111 | `sig_len`, 10 signature words | trailing-byte decode |

Observables (ABI v2 packed word: result 2 | error 6 | depth 3 | top len 2 |
top value 8):

- NULLFAIL fires (`fSuccess = 0`, `nullFail != 0`, `sig_len != 0`): `128`
  (error 32), including when `wire = 0xad` — the guard outranks ordinal 14;
- CHECKSIG true: `10497`; CHECKSIG false: `264` (EVAL_FALSE, depth 1);
- CHECKSIGVERIFY with a failed check and no NULLFAIL: `56` (error 14);
- CHECKSIGVERIFY with a passing check: `8` (empty stack, EVAL_FALSE).

`cell_hashtype` returns `ht | acp<<8 | (ht&0x1f)<<9 | class<<16`: `acp` is
exactly bit 0x80 of the final signature byte, `class` is 2 for SINGLE (0x03),
1 for NONE (0x02) and 0 for every other 5-bit value (ALL-like).  Bits 5..6
are provably ignored.  `sig_len = 0` or `> 80` returns 0 without reading.

## Same-crypto premise

`fSuccess` is the ECDSA checker's verdict; the cell proves the guard and the
CHECKSIG/VERIFY tail for *every* verdict, so it does not depend on how the
verdict is produced.  Agreement between Core's libsecp-backed checker and the
Lean `ScriptChecker` seam is the premise of `docs/DECISION-lax-ecdsa.md` and
is not claimed here.  SCR-111 is structural: no crypto or hash is involved,
and no digest construction is modelled (SCR-140/SWT-042 own that).

## What is *not* claimed

- No DER/LOW_S/STRICTENC encoding gates: the cells start at the checker
  boundary.
- No Λ (sighash preimage) or SHA-256; only the trailing byte's decode.
- `wire` values other than 0xad take the CHECKSIG arm (domain is
  {0xac, 0xad}).
- No R leg (F-HARNESS-002 / F-TOOL-001).
- Alive2 v20 cannot ingest attached TBAA/alias.scope metadata in this shape,
  so the runner strips those optimizer hints from both legs identically.

## SAW notes

The first proof attempt for `cell_hashtype` hit LLVM "Undefined behavior:
addition of an offset to a pointer outside the allocation" for
`sig_len = 285212686`: indexing the 10-word buffer is memory-safe only when
`sig_len <= 80`.  Both legs now totalize to 0 outside [1,80] before reading,
matching the documented buffer domain; the spec was extended the same way.
