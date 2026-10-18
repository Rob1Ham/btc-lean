import Bitcoin.Interpreter.Rules
import Bitcoin.Block.Sigops
import Bitcoin.TxValidation.SigOpsCost

/-! Static counting regressions against GetSigOpCount/CountWitnessSigOps at
both pinned Core revisions. These check resource accounting, including
malformed scripts; they do not assert that those scripts execute successfully. -/

namespace Test.Capstone.Sigops

open Bitcoin.Data Bitcoin.Interpreter

private def bytes (xs : List UInt8) : ByteArray := List.toByteArray xs
private def script (xs : List UInt8) : Script := ⟨bytes xs⟩
private def raw (xs : List UInt8) : Nat := Bitcoin.Interpreter.SigOps.witnessScriptSigOps (bytes xs)
private def ruleCount (xs : List UInt8) (accurate : Bool) : Nat :=
  sigOpCount ((parseWire (bytes xs)).getD []) accurate
private def wrapped (d : ByteArray) : ByteArray := Bitcoin.Script.Parser.pushBytesWire d
private def p2sh : ByteArray := bytes ([0xa9, 0x14] ++ List.replicate 20 0 ++ [0x87])
private def wpkh : ByteArray := bytes ([0, 20] ++ List.replicate 20 1)
private def wsh : ByteArray := bytes ([0, 32] ++ List.replicate 32 1)
private def previous : OutPoint := ⟨bytes (List.replicate 32 0x33), 0⟩
private def tx (ss : ByteArray) (w : List WitnessStack := []) : Tx :=
  { version := 2, vin := [{ prevout := previous, scriptSig := ⟨ss⟩, sequence := 0xffffffff }]
    vout := [{ value := 9, scriptPubKey := script [0x51] }], locktime := 0, witness := w }
private def view (spk : ByteArray) : Bitcoin.Ledger.UtxoSet :=
  fun _ => some ⟨10, 1, false, ⟨spk⟩⟩

private def flaggedCost (spk ss : ByteArray) (p2sh witness : Bool) : Nat :=
  Bitcoin.Block.Sigops.txSigOpCostWithFlags (view spk) (tx ss)
    { p2sh := p2sh, witness := witness }

-- These validate the explicit transaction-cost wrapper; the Core harness
-- separately compares the 28 named raw/per-input counting cases below.
private def wrapperChecks : List (String × Nat × Nat) :=
  let two := { tx (wrapped (bytes [0xac])) with
    vin := (tx (wrapped (bytes [0xac]))).vin ++ (tx (wrapped (bytes [0x52, 0xae]))).vin }
  [("second input uses its own prevout", txP2shSigOps two (fun n => if n == 1 then p2sh else bytes []), 2),
   ("first input uses its own prevout", txP2shSigOps two (fun n => if n == 0 then p2sh else bytes []), 1),
   ("P2SH disabled", flaggedCost p2sh (wrapped (bytes [0x52, 0xae])) false false, 0),
   ("P2SH enabled", flaggedCost p2sh (wrapped (bytes [0x52, 0xae])) true false, 8),
   ("native witness disabled", flaggedCost wpkh (bytes []) true false, 0),
   ("native witness enabled", flaggedCost wpkh (bytes []) true true, 1),
   ("wrapped witness disabled", flaggedCost p2sh (wrapped wpkh) true false, 0),
   ("wrapped witness enabled", flaggedCost p2sh (wrapped wpkh) true true, 1)]

private def checks : List (String × Nat × Nat) :=
  [("accurate per-CMS lookback", ruleCount [0x52, 0xae, 0x53, 0xaf] true, 5),
   ("inaccurate CMS is twenty", ruleCount [0x52, 0xae, 0x53, 0xaf] false, 40),
   ("trailing OP_N adds nothing", ruleCount [0xac, 0x60] true, 1),
   ("intervening opcode clears lookback", ruleCount [0x52, 0x61, 0xae] true, 20),
   ("pushed sigops are data", raw [3, 0xac, 0xae, 0xaf, 0xad], 1),
   ("truncated direct push retains prefix", raw [0xac, 2, 0xae], 1),
   ("truncated PUSHDATA1 length retains prefix", raw [0xac, 0x4c], 1),
   ("truncated PUSHDATA1 payload retains prefix", raw [0x52, 0xae, 0x4c, 2, 0xac], 2),
   ("truncated PUSHDATA2 length retains prefix", raw [0xad, 0x4d, 1], 1),
   ("truncated PUSHDATA4 length retains prefix", raw [0xaf, 0x4e, 0, 0, 0], 20),
   ("P2SH redeem bytes are counted directly", p2shSigOpCount (wrapped (bytes [0x52, 0xae])), 2),
   ("P2SH valid redeem prefix survives", Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps (wrapped (bytes [0xac, 0x4c])), 1),
   ("P2SH non-push prefix is rejected", Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps (bytes [0x76] ++ wrapped (bytes [0xac])), 0),
   ("rule P2SH non-push prefix is rejected", p2shSigOpCount (bytes [0x76] ++ wrapped (bytes [0xac])), 0),
   ("block P2SH non-push prefix is rejected", Bitcoin.Block.Sigops.p2shSigOpCount (view p2sh) (tx (bytes [0x76] ++ wrapped (bytes [0xac]))), 0),
   ("P2SH truncated scriptSig returns zero", Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps (wrapped (bytes [0xac]) ++ bytes [0x4c]), 0),
   ("block truncated scriptSig returns zero", Bitcoin.Block.Sigops.p2shSigOpCount (view p2sh) (tx (wrapped (bytes [0xac]) ++ bytes [0x4c])), 0),
   ("small-int tail clears redeem data", Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps (wrapped (bytes [0xac]) ++ bytes [0x51]), 0),
   ("OP_RESERVED tail clears redeem data", Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps (wrapped (bytes [0xac]) ++ bytes [0x50]), 0),
   ("witness P2WSH retains valid prefix", Bitcoin.Interpreter.SigOps.witnessSigOps 0 (bytes (List.replicate 32 1)) [bytes [0xac, 0x4c]], 1),
   ("wrapped witness requires push-only", Bitcoin.Interpreter.SigOps.p2shWitnessSigOps (bytes [0x76] ++ wrapped wpkh) [], 0),
   ("wrapped P2WPKH counts without witness", Bitcoin.Block.Sigops.witnessSigOps (view p2sh) (tx (wrapped wpkh)), 1),
   ("native P2WPKH counts without witness", Bitcoin.Block.Sigops.witnessSigOps (view wpkh) (tx (bytes [])), 1),
   ("wrapped P2WSH accurate count", Bitcoin.Block.Sigops.witnessSigOps (view p2sh) (tx (wrapped wsh) [[bytes [0x52, 0xae]]]), 2),
   ("native P2WSH accurate count", Bitcoin.Block.Sigops.witnessSigOps (view wsh) (tx (bytes []) [[bytes [0x52, 0xae]]]), 2),
   ("empty witness P2WSH counts zero", Bitcoin.Block.Sigops.witnessSigOps (view wsh) (tx (bytes [])), 0),
   ("future witness counts zero", Bitcoin.Interpreter.SigOps.witnessSigOps 1 (bytes (List.replicate 32 1)) [bytes [0xac]], 0),
   ("legacy malformed script retains prefix", Bitcoin.Block.Sigops.legacySigOpCountScript (script [0xae, 0x4c]), 20)]

def run : IO UInt32 := do
  let mut failures := 0
  for (name, got, expected) in checks do
    let ok := got == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={got}"
    if !ok then failures := failures + 1
  for (name, got, expected) in wrapperChecks do
    let ok := got == expected
    IO.println s!"[WRAP-{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={got}"
    if !ok then failures := failures + 1
  IO.println s!"sigop checks={checks.length + wrapperChecks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.Sigops

def main : IO UInt32 := Test.Capstone.Sigops.run
