import Bitcoin.Capstone.Block

/-! R06: native witness gates must run before incomplete crypto reporting.
Future witness versions retain upgrade rules; Core retroactively applies
Taproot flags except at its named historical exceptions. -/

namespace Test.Capstone.WitnessInputs

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Interpreter

private def bytes (n : Nat) (value : UInt8 := 1) : ByteArray :=
  List.toByteArray (List.replicate n value)
private def script (xs : List UInt8) : Script := ⟨List.toByteArray xs⟩
private def coin (version : UInt8 := 0x51) (size : Nat := 32) : Coin :=
  ⟨10, 0, false, ⟨List.toByteArray [version, size.toUInt8] ++ bytes size⟩⟩
private def spend (ss : Script := Script.empty) (witness : WitnessStack := []) : Tx :=
  { version := 2
    vin := [{ prevout := ⟨bytes 32, 0⟩, scriptSig := ss, sequence := 0xffffffff }]
    vout := [{ value := 9, scriptPubKey := script [0x51] }]
    locktime := 0, witness := [witness] }
private def fail (e : ExecError) : InputVerdict := .fail (.scriptFail 0 0 e)
private def code : InputVerdict → String
  | .pass => "pass"
  | .unjudgedTaproot => "unjudged"
  | .fail (.scriptFail _ _ e) => reprStr e
  | .fail e => e.reason

def run : IO UInt32 := do
  let checks : List (String × InputVerdict × InputVerdict) :=
    [("native v1 nonempty scriptSig", verifyInput 709632 (spend (script [0x51]) [bytes 64]) 0 (coin) 0 0,
        fail .witnessMalleated),
     ("active Taproot empty witness", verifyInput 709632 (spend) 0 (coin) 0 0,
        fail .witnessProgramWitnessEmpty),
     ("scriptSig execution precedes witness dispatch", verifyInput 709632 (spend (script [0x6a])) 0 (coin) 0 0,
        fail .opReturn),
     ("future witness nonempty scriptSig", verifyInput 709632 (spend (script [0x51])) 0 (coin 0x52) 0 0,
        fail .witnessMalleated),
     ("future version empty witness is permitted", verifyInput 709632 (spend) 0 (coin 0x52) 0 0, .pass),
     ("v1 non-32-byte program is upgradable", verifyInput 709632 (spend) 0 (coin 0x51 20) 0 0, .pass),
     ("retroactive Taproot flags reject an empty earlier-height witness", verifyInput 709631 (spend) 0 (coin) 0 0,
        fail .witnessProgramWitnessEmpty),
     ("bad control size is adjudicable", verifyInput 709632 (spend Script.empty
        [List.toByteArray [0x51], List.toByteArray [1]]) 0 (coin) 0 0,
        fail .taprootWrongControlSize),
     ("wrong script-path program binding", verifyInput 709632 (spend Script.empty
        [List.toByteArray [0x51], List.toByteArray [0xc0] ++ bytes 32 0xff]) 0 (coin) 0 0,
        fail .witnessProgramMismatch),
     ("legacy true script control", verifyInput 709632 (spend) 0
        ⟨10, 0, false, script [0x51]⟩ 0 0, .pass),
     ("v0 program length control", verifyInput 709632 (spend) 0 (coin 0 19) 0 0,
        fail .witnessProgramWrongLength),
     ("v0 witness count control", verifyInput 709632 (spend) 0 (coin 0 20) 0 0,
        fail .witnessProgramMismatch)]
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={code expected}, actual={code actual}"
    if !ok then failures := failures + 1
  IO.println s!"witness-input checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.WitnessInputs

def main : IO UInt32 := Test.Capstone.WitnessInputs.run
