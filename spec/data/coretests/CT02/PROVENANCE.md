# CT02 vector provenance

Case set: CT02, 2026-10-16.

## Bitcoin Core ground truth

- Pin: `cce32b16` = full SHA `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (bitcoin/bitcoin master, merge-script commit dated **2026-10-15T08:15:30Z**,
  verified via GitHub REST `GET /repos/bitcoin/bitcoin/commits/cce32b16`).
- No local Core checkout was retained on the capture host; the following files
  were fetched raw at the pin into a workspace outside the repository
  (sha-pinned URLs
  `https://raw.githubusercontent.com/bitcoin/bitcoin/cce32b16/<path>`):

  | file                | lines  | used for                                        |
  |---------------------|--------|-------------------------------------------------|
  | `src/test/coins_tests.cpp` | 1202 | the whole case surface (15 test cases) |
  | `src/coins.cpp`     | 460    | AddCoin/AddCoins/SpendCoin/BatchWrite           |
  | `src/coins.h`       | 825    | Coin/CCoinsCacheEntry/FRESH/DIRTY/AddCoins decl |
  | `src/validation.cpp`| 6424    | UpdateCoins/ConnectBlock/DisconnectBlock/ApplyTxInUndo/IsBIP30Repeat/IsBIP30Unspendable/CheckBlock/RollforwardBlock/VerifyDB/RollbackBlock/DisconnectTip |
  | `src/consensus/tx_verify.cpp` | — | CheckTxInputs error strings + maturity check |
  | `src/index/coinstatsindex.cpp` | — | the ONLY cce32b16 caller of `IsBIP30Unspendable` |

- Every Core claim in `CT02.md` and in `CT02-vectors.py` carries a
  `file:line` anchor into the pinned files above. Line numbers are the
  raw-file line numbers at `cce32b16`.

## ourUtxoSet side (read-only cross-check)

- `spec/core/Bitcoin/Ledger/Interface.lean` (1922 lines, W12) —
  `addedCoins`/`updateCoins`/`updateCoinsL`/`applyTxStepU/L`/
  `applyBlockU/L`/`applyBlock`, theorems `updateCoins_spend_gone`,
  `updateCoins_spend_recreate`, `applyBlockU_no_double_spend`
  (INV-110 freshness form), undo tier `spentUndo`/`undoCoins`/
  `updateCoins_undo` (INV-113).
- `spec/core/Bitcoin/Ledger/HashMap.lean` (276 lines, X13 U1) —
  `insertCoinsM`/`erasePrevoutsM`/`updateCoinsM`/`applyBlockM`.
- `spec/core/Bitcoin/Block/Params.lean` (W06-era BLK-096..108 rows,
  incl. `bip30DisconnectRelaxed` BLK-099, `replayUndos` BLK-106,
  `undoCountOk` BLK-108).
- `spec/core/Bitcoin/Invariants/RC09.lean` (invariants module, INV-104/105/106).
- `spec/core/Bitcoin/Data/Tx.lean` (`Tx.isCoinBase` = vin=[null-prevout]).

Not modified by CT02 (read-only analysis): the Lean tree is untouched;
all CT02 output is new files under `spec/db/findings-af/` and
`spec/vectors/coretests/CT02/` only.

## Vector ID scheme

`ct02-A<n>` BIP30 predicate cross-checks; `ct02-B<n>` AddCoin/ccoins_add;
`ct02-C<n>` SpendCoin/ccoins_spend; `ct02-D<n>` updatecoins_simulation_test
scenarios; `ct02-E<n>` undo/disconnect/reorg-ordering cases;
`ct02-F<n>` inventory rows (whole-test-case level).
See `README.md` for the per-case verdicts and `CT02-vectors.py` for the
golden tables (transcribed from `coins_tests.cpp` literals) and the
Core/ours formula ports.

## Naming note ("ApplyBlockInPlace")

`ApplyBlockInPlace` does **not exist** at `cce32b16` (0 grep hits across
`validation.{h,cpp}`, `coins.{h,cpp}`, `coins_tests.cpp`). The UTXO
apply/undo call sites at the pin are `UpdateCoins` (validation.cpp:1998,
called from ConnectBlock:2598), `DisconnectBlock` (validation.cpp:2178,
called from DisconnectTip:2956, VerifyDB level 3:4703, RollbackBlock:4843),
and `RollforwardBlock` (validation.cpp:4770). The vectors and findings use
the pin's real names. See finding F-CT02-9 in `CT02.md`.
