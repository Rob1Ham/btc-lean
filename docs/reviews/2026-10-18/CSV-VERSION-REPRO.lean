import Bitcoin.Capstone.Block
open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block
private def point : OutPoint := ⟨List.toByteArray (List.replicate 32 1), 0⟩
private def coin : Coin := ⟨10, 0, false, ⟨List.toByteArray [0x51, 0xb2, 0x75, 0x51]⟩⟩
private def tx (version : Int32) : Tx :=
  { version := version, vin := [{ prevout := point, scriptSig := Script.empty, sequence := 1 }],
    vout := [⟨9, ⟨List.toByteArray [0x51]⟩⟩], locktime := 0, witness := [] }
private def verdict (version : Int32) : String :=
  match applyTx 500000 (tx version) 1 [(point, coin)] with
  | .error (.scriptFail _ _ e) => reprStr e
  | .error e => e.reason
  | .ok (_, a, b) => s!"ok:{a}:{b}"
#eval verdict (-1)
#eval verdict 2
