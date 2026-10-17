# CT02 vectors — coins_tests.cpp @cce32b16 vs ourUtxoSet fold/undo

`CT02-vectors.py` (python3, zero deps, exit 0 = pass). Provenance in
`PROVENANCE.md`. Findings in `spec/db/findings-af/CT02.md`.

## Method

Golden tables are transcribed **verbatim** from the `coins_tests.cpp`
literals at the pin (`cce32b16`); the "core" functions are line-anchored
transcriptions of the actual Core code; the "ours" functions are formula
transcriptions of the Lean definitions (`Ledger/Interface.lean` W12,
`Block/Params.lean`, read-only cross-check). Every vector asserts
core-port == golden, and ours-formula == Core-verdict — except the one
**RECORDED DIVERGENCE**, which is asserted *as* a divergence.

## Vector index

| module | vectors | coverage | verdict |
|---|---|---|---|
| A | ct02-A1..A4 | BIP30 enforcement predicate (Core `validation.cpp:2401+2461+2466` vs ours `Interface.lean:340-342`) over 12 boundary heights; the three BIP30 height-pairs | **1 DIVERGENCE** (A2, h=227931 = F-CT02-2) + 1 structural (A3, hash pins) |
| B | ct02-B1..B2 | `AddCoin`/`ccoins_add`: all 54 golden rows (18 cache-states × 3 bases) + the 12 `EX_OVERWRITE_UNSPENT` throw-rows + consensus projection (added-wins, BIP30 gate) | MATCH (consensus-visible) |
| C | ct02-C1..C2 | `SpendCoin`/`ccoins_spend`: all 15 golden rows + consensus projection (coin gone; `assert(is_spent)` vs ours' total fn) | MATCH (consensus-visible) |
| D | ct02-D1a,D1b,D1c,D2,D3,D4,D5,D6 | `updatecoins_simulation_test` (L325-515): duplicate-coinbase connect (elided/enforced/spent-overwrite), spend-duplicate (no resurrect), undo/reconnect, height stamping | MATCH (consensus projection) |
| E | ct02-E1..E4 | undo tier: BIP30-disconnect-pair overwrite (h5 fails, c1 lost), clean round trip (DISCONNECT_OK), same-block re-create reorg ordering (E3), coinbase undoDummy (E4); the 3 UNCLEAN-consumer table | MATCH (coin-level) + 2 GAPS (verdict tier, block-fold) |
| F | ct02-F1..F15 | inventory of all 15 test cases at the pin | 3 MATCH / 12 NOT-MODELED-BY-DESIGN |

## Notable rows

- **ct02-A2** (the one divergence): `core_bip30_check_runs(227931)=True`
  vs `ours_bip30Enforced(227931)=False` — ours' BIP34 elide-window is
  `[227931, 1983702)`, Core's is `[227932, 1983702)` ∧ hash-pinned
  (`pprev->GetAncestor(BIP34Height)` is `nullptr` at 227931 ⇒ the 2461
  conjunct is vacuous ⇒ enforced). No consensus-behavior divergence
  found (BIP34 @ `ContextualCheckBlock` rejects duplicate coinbases ≥
  227931 first; see findings F-CT02-2).
- **ct02-B1** the AddCoin flag law recovered from the golden rows:
  `flags = pre | DIRTY | (FRESH if !possible_overwrite && !pre_dirty)`
  — a **pre-existing FRESH survives AddCoin** (`SetDirty`=`AddFlags`,
  additive, `coins.cpp:108-113`), and AddCoin **never consults the
  parent view** (emplace, `coins.cpp:85`): the same-layer throw
  (`coins.cpp:87-89`) is not a cross-layer BIP30 backstop.
- **ct02-D1c** (the 91812 case): the (91722, 91812) pair is **not** in
  `IsBIP30Repeat` — Core's BIP30 check *runs* at 91812 and passes
  because 91722's coin was already **spent** (`HaveCoin=false`);
  AddCoins(po=coinbase) then overwrites the *spent* coin (no loss).
  ours: spent = `none` ⇒ `bip30Collision=false` ⇒ ok. This is why the
  connect-pair {91842,91880} and the disconnect-pair {91722,91812} are
  **different pairs** (three-pair map, ct02-A4).
- **ct02-E1** (h5 = the overwrite boundary): `updateCoins_undo`'s h5
  fails exactly where a duplicate coinbase overwrote an unspent coin —
  and Core's undo record **never records overwrites** (vprevout holds
  only its own SpendCoins, `validation.cpp:2004-2010`) ⇒ the
  overwritten coin is lost in ours *and* Core (BIP30-exception blocks).
- **ct02-E3** (reorg undo ordering): block [A, B] with B re-creating p
  mid-block — per-tx undo payloads consumed in reverse restore the
  exact pre-state (`u . undoB . undoA = u`); B's payload is empty
  (A spent p ⇒ `spentUndo(u1,B)=[]`) = Core's undo-record gap for
  re-creates (`disconnected_coins`-style reconnects can't restore p
  either).

## Status

- 0 Lean changes (read-only cross-check; no `lake build` needed).
- Run: `python3 spec/vectors/coretests/CT02/CT02-vectors.py` →
  `ALL CHECKS PASS (incl. the one RECORDED DIVERGENCE ct02-A2 @ h=227931)`.
- Not folded into `db/vector_ids.yaml` (the codegen inventory owns the map;
  see PROPOSED P4 in the findings).
