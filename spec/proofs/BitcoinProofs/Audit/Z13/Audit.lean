import Bitcoin.Ledger.Interface
import Bitcoin.Block.Connect
import Bitcoin.Block.Params
import Bitcoin.Capstone.Pow

/-!
# Z13 dark-corner audit — genesis = empty UTXO set & OP_RETURN never stored

2026-10-16. Python3 probe:
`z13_probe.py` (ALL PROBES OK).

Ground truth: Bitcoin Core @ `cce32b1682d86076ee71c10f9788c48d44458a263`:
  - `src/kernel/chainparams.cpp:47-50` — "the output of its generation
    transaction cannot be spent since it did not originally exist in the
    database" (unspendability is POSITIONAL — by omission, not a script rule);
  - `src/validation.cpp:2336-2342` — ConnectBlock's genesis special case
    returns BEFORE UpdateCoins: genesis state = tip set, UTXO untouched (∅);
  - `src/script/script.h:564-567` — `IsUnspendable() = (size>0 && first ==
    OP_RETURN) || size > MAX_SCRIPT_SIZE(10000)`;
  - `src/coins.cpp:82` — `AddCoin`: `if (coin.out.scriptPubKey.IsUnspendable())
    return;` — OP_RETURN outputs are NEVER inserted into the coin set;
  - `src/validation.cpp:2213` — DisconnectBlock symmetric `IsUnspendable` guard
    (`Bitcoin.Block.Params.disconnectRelevant`, BLK-107, already in-tree).

Review-1 rows covered: BLK-093/094 (C2), BLK-109/110/111/112 (C1). In-tree
capture points: `Bitcoin.Ledger.scriptUnspendable` (BLK-094/INV-112),
`Bitcoin.Ledger.addedCoins` + theorem `addedCoins_lookup_none_of_unspendable`
(BLK-093, INV-112 — status: proven), `Bitcoin.Block.Connect.connectGenesis` +
`connectGenesis_utxo_unchanged` (BLK-109), `Bitcoin.Ledger.emptyUtxo` /
`viewOf_nil` / `genesis_coin_isSome` (BLK-110), `Bitcoin.Block.Params.
genesisHeader` / `genesisCoinbaseTx` (BLK-111/112).

All pins below are kernel-computed (`decide`/`rfl`, no `native_decide`, no
mathlib) so the axiom footprint stays in the charter subset. The
`maxRecDepth` bump is required because the pins evaluate real byte-level
serializations (serTx ≈ 224 B, scripts ≤ 10001 B) whose structural
recursion exceeds the default depth.
-/

set_option maxRecDepth 100000

namespace Bitcoin.Proofs.Audit.Z13

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Block.Connect Bitcoin.Block.Params
open Bitcoin.Capstone.Pow

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else none

private def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-- `n` copies of byte `b` (toolchain has no `ByteArray.replicate`). -/
private def repBytes (n : Nat) (b : UInt8) : ByteArray := ByteArray.mk (Array.replicate n b)

/-- The `> MAX_SCRIPT_SIZE` arm of `IsUnspendable` (script.h:566, right
disjunct) — generic form, no concrete byte blob needed. -/
theorem scriptUnspendable_of_gt_max (s : Script) (h : MAX_SCRIPT_SIZE < s.bytes.size) :
    scriptUnspendable s = true := by
  unfold scriptUnspendable
  rw [Bool.or_eq_true]
  exact Or.inr (decide_eq_true_iff.mpr h)

/-! ## C2 — OP_RETURN outputs are never inserted into the UTXO set -/

/-! ### the IsUnspendable drop table (script/script.h:564-567) -/

-- T1: bare 1-byte OP_RETURN → unspendable (python probe row 1).
example : scriptUnspendable ⟨fromHex "6a"⟩ = true := by decide

-- T2: the BIP141 witness-commitment output `6a24aa21a9ed ‖ 32B` (38 bytes)
-- → unspendable: SegWit commitments never enter the UTXO set (probe row 2).
example : scriptUnspendable ⟨fromHex
  "6a24aa21a9ed1122334455667788990011223344556677889900aabbccddeeff001122334455"⟩ = true := by
  decide

-- T3: EMPTY script → spendable! Core requires `size() > 0` — an empty
-- scriptPubKey IS stored (probe row 4). Note: rules.yaml BLK-094's summary
-- wording "script empty or first byte OP_RETURN ⇒ unspendable" is wrong on
-- the empty half; the Lean def matches Core, not the row text.
example : scriptUnspendable Script.empty = false := by decide

-- T4: P2PKH 25B → spendable (probe row 5).
example : scriptUnspendable ⟨fromHex "76a914ab1122334455667788990011223344556677889988ac"⟩
  = false := by decide

-- T5/T6: the MAX_SCRIPT_SIZE boundary at exactly 10000 (probe rows 7-8).
example : (repBytes 10000 0x51).size = 10000 := by decide
example : scriptUnspendable ⟨repBytes 10000 0x51⟩ = false := by decide
example : (repBytes 10001 0x51).size = 10001 := by decide
example : scriptUnspendable ⟨repBytes 10001 0x51⟩ = true := by decide

/-! ### behavioral: a 2-output tx — the OP_RETURN coin is dropped -/

-- vout[0] = 333 sat OP_RETURN, vout[1] = 25000 sat P2PKH (probe AddCoins run).
def opTx : Tx :=
  { version := 1
    vin := [⟨⟨repBytes 32 1, 0⟩, Script.empty, 0xffffffff⟩]
    vout := [⟨333, ⟨fromHex "6a"⟩⟩,
             ⟨25000, ⟨fromHex "76a914ab1122334455667788990011223344556677889988ac"⟩⟩]
    locktime := 0, witness := [] }

-- exactly ONE coin enters the set (coins.cpp:82 drop, not a lookup effect) …
example : (addedCoins opTx (txidPreimageKey opTx) 0).length = 1 := by decide

-- … the OP_RETURN outpoint (txid, 0) is ABSENT — INV-112's executable half …
example : (coinLookup (addedCoins opTx (txidPreimageKey opTx) 0)
    (txidPreimageKey opTx OutPoint.null 0)).isSome = false := by decide

-- … a spend of it would find nothing (`bad-txns-inputs-missing-or-spent`
-- territory; Core: HaveCoin(txid,0) = false), while the P2PKH coin at
-- (txid, 1) is present with the exact value/height …
example : (coinLookup (addedCoins opTx (txidPreimageKey opTx) 0)
    (txidPreimageKey opTx OutPoint.null 1)).isSome = true := by decide
example : (coinLookup (addedCoins opTx (txidPreimageKey opTx) 0)
    (txidPreimageKey opTx OutPoint.null 1)).map (fun c => c.value) = some 25000 := by
  decide
example : (coinLookup (addedCoins opTx (txidPreimageKey opTx) 0)
    (txidPreimageKey opTx OutPoint.null 1)).map (fun c => c.height) = some 0 := by
  decide

-- … and the drop survives the executable UpdateCoins fold (updateCoinsL
-- prepends addedCoins verbatim — no separate OP_RETURN re-insertion path).
example : (coinLookup (updateCoinsL [] opTx (txidPreimageKey opTx) 0)
    (txidPreimageKey opTx OutPoint.null 0)).isSome = false := by decide

-- the >10k arm drops too (probe boundary row):
def bigTx : Tx :=
  { version := 1
    vin := [⟨⟨repBytes 32 1, 0⟩, Script.empty, 0xffffffff⟩]
    vout := [⟨1, ⟨repBytes 10001 0x51⟩⟩]
    locktime := 0, witness := [] }
example : (addedCoins bigTx (txidPreimageKey bigTx) 0).length = 0 := by decide

-- Core-side theorem (in-tree, BLK-093/INV-112, status: proven) this file
-- byte-pins: `Bitcoin.Ledger.addedCoins_lookup_none_of_unspendable`
-- (`spec/core/Bitcoin/Ledger/Interface.lean:717`).

/-! ## C1 — genesis = EMPTY UTXO set; the coinbase unspendable by OMISSION -/

/-! ### the genesis coinbase itself (BLK-111/112, chainparams.cpp:38-72) -/

example : genesisCoinbaseTx.isCoinBase = true := by decide
example : (genesisCoinbaseTx.vout.getD 0 ⟨0, Script.empty⟩).value = 5000000000 := by decide
example : (genesisCoinbaseTx.vout.getD 0 ⟨0, Script.empty⟩).scriptPubKey.bytes.size = 67 := by
  decide
-- DECISIVE: the 50 BTC output's script is SPENDABLE (67-byte P2PK, first
-- byte 0x41 ≠ OP_RETURN, size ≤ 10000) — so its absence from the UTXO set
-- comes from the CONNECT path (validation.cpp:2336-2342), NOT from
-- IsUnspendable. Exactly Core's chainparams.cpp:47-50 comment.
example : scriptUnspendable ⟨genesisScriptPubKey⟩ = false := by decide

/-! ### the genesis connection (BLK-109/110, validation.cpp:2336-2342) -/

-- the special case: state untouched (UTXO stays whatever it was — at
-- genesis, EMPTY), only the tip pointer is set …
example : (connectGenesis [] genesisHeader).1 = [] := rfl
example : (connectGenesis [] genesisHeader).2 = headerHash genesisHeader := rfl

-- THE empty-set pin: the genesis coinbase outpoint is ABSENT from the
-- post-genesis view (probe: |utxo| = 0 after the special-case path).
example : viewOf (connectGenesis [] genesisHeader).1
    (txidPreimageKey genesisCoinbaseTx OutPoint.null 0) = none := rfl

-- the pre-genesis state IS the empty view (BLK-110: `emptyUtxo`), and the
-- fold over no transactions preserves it …
example : applyBlock emptyUtxo [] 0 = Except.ok emptyUtxo := rfl

-- … COUNTERFACTUAL: had genesis gone through the NORMAL connect path, the
-- 50 BTC coin WOULD have been created with coinbase bit, height 0, full
-- value — this is what "unspendable by omission, not by rule" means (the
-- normal path is simply never taken for the genesis block).
example : (coinLookup (updateCoinsL [] genesisCoinbaseTx
    (txidPreimageKey genesisCoinbaseTx) 0)
    (txidPreimageKey genesisCoinbaseTx OutPoint.null 0)).isSome = true := by decide
example : (coinLookup (updateCoinsL [] genesisCoinbaseTx
    (txidPreimageKey genesisCoinbaseTx) 0)
    (txidPreimageKey genesisCoinbaseTx OutPoint.null 0)).map (fun c => c.value)
  = some 5000000000 := by decide
example : (coinLookup (updateCoinsL [] genesisCoinbaseTx
    (txidPreimageKey genesisCoinbaseTx) 0)
    (txidPreimageKey genesisCoinbaseTx OutPoint.null 0)).map (fun c => c.height)
  = some 0 := by decide
example : (coinLookup (updateCoinsL [] genesisCoinbaseTx
    (txidPreimageKey genesisCoinbaseTx) 0)
    (txidPreimageKey genesisCoinbaseTx OutPoint.null 0)).map (fun c => c.isCoinbase)
  = some true := by decide

-- Generic capture (in-tree, cited): `Bitcoin.Ledger.emptyUtxo` (BLK-110),
-- `emptyUtxo_lookup`, `viewOf_nil`, `genesis_coin_isSome` — and
-- `Bitcoin.Block.Connect.connectGenesis_utxo_unchanged` (BLK-109).

end Bitcoin.Proofs.Audit.Z13
