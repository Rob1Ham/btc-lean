# Cell `checksig/C-L-checksig-bip66`

## What is proved

Three closed functions per leg, over symbolic 32-bit deployment height,
block height, exception class and base flag word:

| Function | Rule |
|---|---|
| `cell_dersig_flag` | `baseFlags(exc) OR (height >= bip66_height ? DERSIG : 0)` |
| `cell_dersig_flag_mainnet` | same with the pinned mainnet height 363725 |
| `cell_dersig_or` | arbitrary 4-bit base word OR the deployment DERSIG bit |

`baseFlags` follows `GetBlockScriptFlags`'s exception replacement
(no exception → P2SH|WITNESS|TAPROOT; BIP16 exception → NONE; taproot
exception → P2SH|WITNESS).  Heights are bounded to [0, 2^31) so Core's signed
`nHeight >= DeploymentHeight` compare coincides with the cell's unsigned
compare.

## What is *not* claimed

- No transaction, script, or signature check: this is the DERSIG **flag
  derivation** only.
- The chainstate lookup and `DeploymentActiveAt` call are reduced to their
  value for a buried deployment (a plain height compare at the pin).
- No R leg: the pinned rbitcoin shim has no typed flag/error surface for
  block validation (F-HARNESS-002).
- Alive2 v20 cannot ingest attached TBAA/alias.scope metadata in this shape,
  so the runner strips those optimizer hints from both legs identically.
