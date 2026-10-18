import Bitcoin.Capstone.Block

/-! R18: exercise CSV through the funded public transaction engine.
Int32 stores the wire bits; Core's CheckSequence compares them as uint32_t.
These are conditional supplied UTXO fixtures, not historical-chain claims. -/

namespace Test.Capstone.CsvVersion

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block

private def point : OutPoint := ⟨List.toByteArray (List.replicate 32 1), 0⟩
private def script (xs : List UInt8) : Script := ⟨List.toByteArray xs⟩
private def coin (operand : List UInt8) : Coin :=
  ⟨10, 0, false, script (operand ++ [0xb2, 0x75, 0x51])⟩
private def spend (version : Int32) (sequence : UInt32) : Tx :=
  { version := version
    vin := [{ prevout := point, scriptSig := Script.empty, sequence := sequence }]
    vout := [⟨9, script [0x51]⟩], locktime := 0, witness := [] }

private def verdict (version : Int32) (sequence : UInt32 := 1)
    (operand : List UInt8 := [0x51]) (height : UInt32 := 500000) : String :=
  match applyTx height (spend version sequence) 1 [(point, coin operand)] with
  | .error (.scriptFail _ _ e) => reprStr e
  | .error e => e.reason
  | .ok (_, ok, unjudged) => s!"ok:{ok}:{unjudged}"

def run : IO UInt32 := do
  let checks : List (String × String × String) :=
    [("wire ffffffff version", verdict (-1), "ok:1:0"),
     ("wire fffffffe version", verdict (-2), "ok:1:0"),
     ("wire 80000000 version", verdict (-2147483648), "ok:1:0"),
     ("wire 80000001 version", verdict (-2147483647), "ok:1:0"),
     ("wire 7fffffff version", verdict 2147483647, "ok:1:0"),
     ("version two control", verdict 2, "ok:1:0"),
     ("version three control", verdict 3, "ok:1:0"),
     ("version zero rejects", verdict 0, "Bitcoin.Interpreter.ExecError.unsatisfiedLocktime"),
     ("version one rejects", verdict 1, "Bitcoin.Interpreter.ExecError.unsatisfiedLocktime"),
     ("high-bit version insufficient sequence", verdict (-1) 0,
        "Bitcoin.Interpreter.ExecError.unsatisfiedLocktime"),
     ("high-bit version disabled input", verdict (-1) 0x80000001,
        "Bitcoin.Interpreter.ExecError.unsatisfiedLocktime"),
     ("high-bit version type mismatch", verdict (-1) 0x00400001,
        "Bitcoin.Interpreter.ExecError.unsatisfiedLocktime"),
     ("high-bit version time equality", verdict (-1) 0x00400001 [3, 1, 0, 0x40], "ok:1:0"),
     ("high-bit version time overrun", verdict (-1) 0x00400001 [3, 2, 0, 0x40],
        "Bitcoin.Interpreter.ExecError.unsatisfiedLocktime"),
     ("high-bit version reserved sequence bits", verdict (-1) 0x00010001, "ok:1:0"),
     ("operand disable flag skips old version gate", verdict 1 0xffffffff [5, 0, 0, 0, 0x80, 0],
        "ok:1:0"),
     ("negative operand precedes version gate", verdict (-1) 1 [0x4f],
        "Bitcoin.Interpreter.ExecError.negativeLocktime"),
     ("CSV flag off before activation", verdict (-1) 0 [0x51] 419327, "ok:1:0")]
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  return if failures == 0 then 0 else 1

end Test.Capstone.CsvVersion

def main : IO UInt32 := Test.Capstone.CsvVersion.run
