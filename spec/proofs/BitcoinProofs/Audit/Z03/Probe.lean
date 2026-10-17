import Bitcoin.TxValidation.Interface
import Bitcoin.Interpreter.Defs

open Bitcoin.Data Bitcoin.TxValidation Bitcoin.Interpreter Bitcoin.Crypto.Seam

-- A: does Except have DecidableEq out of the box?
example : DecidableEq (Except TxError Amount) := by infer_instance

deriving instance DecidableEq for Except

-- B: after the deriving, the checkTxInputs decide should synthesize + reduce
def bigCoinUtxo : OutPoint → Option Bitcoin.Ledger.Coin := fun _ =>
  some ⟨MAX_MONEY + 1, 0, false, ⟨ByteArray.empty⟩⟩

def inputOorTx : Tx :=
  { version := 1
    vin := [⟨⟨(List.replicate 32 (7 : UInt8)).foldl (fun acc b => acc.push b) ByteArray.empty, 0⟩,
            ⟨ByteArray.empty⟩, 0xffffffff⟩]
    vout := [⟨MAX_MONEY, ⟨ByteArray.empty⟩⟩]
    locktime := 0, witness := [] }

example : checkTxInputs inputOorTx bigCoinUtxo 200
    = Except.error TxError.badTxnsInputvaluesOutOfRange := by decide

-- C: interpreter decide after deriving
example : evalScriptBytes 100 {} default
    ((List.replicate 6 (0 : UInt8)).foldl (fun acc b => acc.push b) ByteArray.empty) []
    default SigVersion.base default
    = Except.error ExecError.disabledOpcode := by decide

-- D: abstract ByteArray self-BEq: lawful?
example : LawfulBEq ByteArray := by infer_instance

example (c : ByteArray) : (c == c) = true := by simp
