import Bitcoin.Capstone.Block

/-!
# Monetary gates in the live capstone transaction fold

These cases call `applyTx`, rather than the isolated `checkTxInputs`
helper. They cover the missing composition identified as R01 in the
2026-10-18 repository review. No cryptographic oracle is needed: the
available coins use OP_TRUE scripts, so only monetary validation can
reject the inflation and input-range cases.

These are executable regression checks, not kernel proof declarations.
Run: `cd spec/core && lake env lean --run Test/Capstone/ValueChecks.lean`.
-/

namespace Test.Capstone.ValueChecks

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block

private def previous (n : UInt32 := 0) : OutPoint :=
  ⟨List.toByteArray (List.replicate 32 0x11), n⟩

private def coin (value : Amount) : Coin :=
  ⟨value, 100, false, scriptOf [0x51]⟩

private def spend (value : Amount) : Tx :=
  { version := 1
    vin := [{ prevout := previous, scriptSig := Script.empty, sequence := 0xFFFFFFFF }]
    vout := [{ value := value, scriptPubKey := scriptOf [0x51] }]
    locktime := 0
    witness := [] }

private def reason (tx : Tx) (view : List (OutPoint × Coin)) : String :=
  match applyTx 200 tx 0 view with
  | .ok _ => "ok"
  | .error e => e.reason

private def twoInputSpend : Tx :=
  { spend 1 with
    vin := [{ prevout := previous 0, scriptSig := Script.empty, sequence := 0xFFFFFFFF },
            { prevout := previous 1, scriptSig := Script.empty, sequence := 0xFFFFFFFF }] }

private def childSpend (value : Amount) : Tx :=
  { spend value with
    vin := [{ prevout := txidKey (spend 9) OutPoint.null 0,
              scriptSig := Script.empty, sequence := 0xFFFFFFFF }] }

private def foldReason (txs : List Tx) : String :=
  match applyTxs 200 txs 0 [(previous, coin 10)] 0 0 with
  | .ok _ => "ok"
  | .error e => e.reason

private def cases : List (String × Tx × List (OutPoint × Coin) × String) :=
  [ ("input value below outputs", spend 2, [(previous, coin 1)],
      "bad-txns-in-belowout"),
    ("input coin above MAX_MONEY", spend 1, [(previous, coin (MAX_MONEY + 1))],
      "bad-txns-inputvalues-outofrange"),
    ("negative input coin", spend 0, [(previous, coin (-1))],
      "bad-txns-inputvalues-outofrange"),
    ("running input sum above MAX_MONEY", twoInputSpend,
      [(previous 0, coin MAX_MONEY), (previous 1, coin MAX_MONEY)],
      "bad-txns-inputvalues-outofrange"),
    ("input amount failure precedes script failure", spend 2,
      [(previous, { coin 1 with scriptPubKey := scriptOf [0x00] })],
      "bad-txns-in-belowout"),
    ("input coin at MAX_MONEY", spend 1, [(previous, coin MAX_MONEY)], "ok"),
    ("running input sum at MAX_MONEY", twoInputSpend,
      [(previous 0, coin (MAX_MONEY - 1)), (previous 1, coin 1)], "ok"),
    ("valid zero-fee spend", spend 1, [(previous, coin 1)], "ok"),
    ("valid positive-fee spend", spend 0, [(previous, coin 1)], "ok"),
    ("missing input", spend 1, [], "bad-txns-inputs-missingorspent"),
    ("immature coinbase input", spend 1,
      [(previous, { coin 1 with height := 150, isCoinbase := true })],
      "bad-txns-premature-spend-of-coinbase") ]

def run : IO UInt32 := do
  let checks := cases.map (fun (name, tx, view, expected) =>
      (name, reason tx view, expected)) ++
    [("same-block spend uses the new coin value", foldReason [spend 9, childSpend 8], "ok"),
     ("same-block inflation is rejected", foldReason [spend 9, childSpend 10],
       "bad-txns-in-belowout")]
  let results ← checks.mapM fun (name, actual, expected) => do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    return ok
  return if results.all id then 0 else 1

end Test.Capstone.ValueChecks

def main : IO UInt32 := Test.Capstone.ValueChecks.run
