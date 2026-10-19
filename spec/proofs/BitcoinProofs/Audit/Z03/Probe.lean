import Bitcoin.TxValidation.Interface
import Bitcoin.Interpreter.Defs

open Bitcoin.Data Bitcoin.TxValidation Bitcoin.Interpreter Bitcoin.Crypto.Seam

/-! # Z03 probe: kernel decidability of the validation/interpreter results

This is an exploratory probe, not a consensus theorem. Two facts are
recorded here:

* `Except` has no `DecidableEq` instance in the pinned toolchain, so a
  local instance is derived before the `checkTxInputs`/`evalScriptBytes`
  `decide` checks.
* `ByteArray` has a `BEq` instance but no registered `LawfulBEq`
  instance. Reflexivity `(c == c) = true` is still a kernel fact; it
  follows from `Array.isEqv_self` over the underlying byte array.
-/

-- A: `Except` has no `DecidableEq` out of the box; derive it locally.
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

-- C: six `OP_0`s are six empty pushes (they are not disabled opcodes).
example : evalScriptBytes 100 {} default
    ((List.replicate 6 (0 : UInt8)).foldl (fun acc b => acc.push b) ByteArray.empty) []
    default SigVersion.base default
    = Except.ok (List.replicate 6 ByteArray.empty) := by decide

-- D: `ByteArray` has no registered `LawfulBEq`, but its BEq is reflexive.
example (c : ByteArray) : (c == c) = true := by
  simp [BEq.beq, ByteArray.beq, Array.isEqv_self]
