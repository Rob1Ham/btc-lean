import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-!
Executable regressions for R02: subsidy and checked-fee funding in the
public block validator. The genesis bytes supply a real PoW/merkle fixture.
The supplied replay height is deliberately varied: at height 210000 its
50 BTC coinbase exceeds that height's 25 BTC subsidy. This tests the
adapter's monetary gate, not the reachability of that header in a chain.
-/

namespace Test.Capstone.BlockFunding

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Serialization

private def publicReason (height : UInt32) : String :=
  let raw := encodeBlock Bitcoin.Block.Params.genesisHeader [Bitcoin.Block.Params.genesisCoinbaseTx]
  match validateBlock raw { height := height, prevHash := Bitcoin.Block.Params.genesisHeader.hashPrevBlock,
                            utxo := [] } with
  | .ok _ => "ok"
  | .error e => e.reason

private def previous (n : UInt32) : OutPoint :=
  ⟨List.toByteArray (List.replicate 32 0x22), n⟩

private def coin (value : Amount) (script : Script := scriptOf [0x51]) : Coin :=
  ⟨value, 100, false, script⟩

private def spend (n : UInt32) (value : Amount) : Tx :=
  { version := 1
    vin := [{ prevout := previous n, scriptSig := Script.empty, sequence := 0xFFFFFFFF }]
    vout := [{ value := value, scriptPubKey := scriptOf [0x51] }]
    locktime := 0, witness := [] }

private def cb (value : Amount) : Tx :=
  { version := 1
    vin := [{ prevout := OutPoint.null, scriptSig := scriptOf [0x01, 0x01], sequence := 0xFFFFFFFF }]
    vout := [{ value := value, scriptPubKey := scriptOf [0x51] }]
    locktime := 0, witness := [] }

private def fundingReason (height : UInt32) (reward : Amount) (txs : List Tx := [])
    (view : List (OutPoint × Coin) := []) : String :=
  match applyBlockTransactions height (cb reward :: txs) view with
  | .ok _ => "ok"
  | .error e => e.reason

private def parent : Tx := spend 0 9
private def child : Tx :=
  { spend 0 8 with vin := [{ prevout := txidKey parent OutPoint.null 0,
                             scriptSig := Script.empty, sequence := 0xFFFFFFFF }] }

private def feeTotal : String :=
  match applyTxsWithFees 200 [cb 5000000002, parent, child] 0
      [(previous 0, coin 10)] 0 0 0 with
  | .ok (_, fees) => toString fees
  | .error e => e.reason

def run : IO UInt32 := do
  let checks := [
    ("public validator accepts the subsidy boundary", publicReason 200, "ok"),
    ("public validator rejects coinbase above the halved subsidy", publicReason 210000,
      "bad-cb-amount"),
    ("exact zero-fee reward", fundingReason 200 5000000000, "ok"),
    ("reward over subsidy by one satoshi", fundingReason 200 5000000001, "bad-cb-amount"),
    ("unclaimed subsidy is allowed", fundingReason 200 0, "ok"),
    ("exact subsidy plus fee", fundingReason 200 5000000005 [spend 0 5]
      [(previous 0, coin 10)], "ok"),
    ("reward over subsidy plus fee by one", fundingReason 200 5000000006 [spend 0 5]
      [(previous 0, coin 10)], "bad-cb-amount"),
    ("same-block fees use evolving coins", fundingReason 200 5000000002 [parent, child]
      [(previous 0, coin 10)], "ok"),
    ("same-block fees cannot fund an extra satoshi", fundingReason 200 5000000003 [parent, child]
      [(previous 0, coin 10)], "bad-cb-amount"),
    ("checked fee total excludes coinbase and includes child", feeTotal, "2"),
    ("accumulated fees at MAX_MONEY", fundingReason 200 MAX_MONEY [spend 0 0]
      [(previous 0, coin MAX_MONEY)], "ok"),
    ("accumulated fees above MAX_MONEY", fundingReason 200 0 [spend 0 0, spend 1 0]
      [(previous 0, coin MAX_MONEY), (previous 1, coin 1)],
      "bad-txns-accumulated-fee-outofrange"),
    ("fee accumulation failure precedes script failure", fundingReason 200 0 [spend 0 0, spend 1 0]
      [(previous 0, coin MAX_MONEY), (previous 1, coin 1 (scriptOf [0x00]))],
      "bad-txns-accumulated-fee-outofrange"),
    ("script failure precedes final reward failure", fundingReason 200 5000000001 [spend 0 10]
      [(previous 0, coin 10 (scriptOf [0x00]))], "script-verify-error"),
    ("last block before halving", fundingReason 209999 5000000000, "ok"),
    ("first block after halving", fundingReason 210000 2500000000, "ok"),
    ("halved reward plus one", fundingReason 210000 2500000001, "bad-cb-amount"),
    ("epoch 32 last satoshi", fundingReason 6720000 1, "ok"),
    ("epoch 33 no subsidy", fundingReason 6930000 1, "bad-cb-amount"),
    ("epoch 33 fee-only reward", fundingReason 6930000 5 [spend 0 5]
      [(previous 0, coin 10)], "ok")]
  let results ← checks.mapM fun (name, actual, expected) => do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    return ok
  return if results.all id then 0 else 1

end Test.Capstone.BlockFunding

def main : IO UInt32 := Test.Capstone.BlockFunding.run
