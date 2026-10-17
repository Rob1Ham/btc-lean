import Bitcoin.Capstone.Block

/-! PDW67b — route B row face (C3) -/

namespace BitcoinProofs.AF.PDW67b

open Bitcoin.Interpreter Bitcoin.Capstone.Block Bitcoin.Capstone.RealChecker Bitcoin.Activation Bitcoin.Data

/-! ## SWT-068 — per-input scheme dispatch (taproot lane vs adjudicated) -/

@[rule "SWT-068"]
theorem verifyInput_taproot_unjudged {height : UInt32} {tx : Tx} {i : Nat}
    {coin : Bitcoin.Ledger.Coin} {txIdx inputIdx : Nat}
    (h : isTaprootProgram coin.scriptPubKey.bytes = true) :
    verifyInput height tx i coin txIdx inputIdx = .unjudgedTaproot := by
  simp [verifyInput, h]

/-- In-bounds `getD` is the ordinary index (independent of the default). -/
private theorem getD_eq_getElem {α : Type} {l : List α} {i : Nat} (h : i < l.length)
    (a : α) : l.getD i a = l[i] := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem h]
  rfl

/-- SWT-068 (per-input dispatch, adjudicated lane): when the prevout's
scriptPubKey is **not** a v1+ witness program, this input takes the
`verifyScriptFull` (BASE / WITNESS_V0) lane — decided solely by this
input's own `coin`, `vin[i]` and `witness[i]`. -/
@[rule "SWT-068"]
theorem verifyInput_adjudicated_eq {height : UInt32} {tx : Tx} {i : Nat}
    {coin : Bitcoin.Ledger.Coin} {txIdx inputIdx : Nat}
    (h : isTaprootProgram coin.scriptPubKey.bytes = false)
    (hvin : i < tx.vin.length) (hwit : i < tx.witness.length) :
    verifyInput height tx i coin txIdx inputIdx =
      (match verifyScriptFull
        (tx.vin[i].scriptSig.bytes.size +
          coin.scriptPubKey.bytes.size +
          (tx.witness[i].map (·.size)).foldl Nat.add 0 + 10)
        (getBlockScriptFlags height) default
        tx.vin[i].scriptSig.bytes coin.scriptPubKey.bytes
        tx.witness[i] (realCheckerOf tx i coin.value) with
      | .ok => .pass
      | .unjudged => .unjudgedTaproot
      | .fail e => .fail (CapError.scriptFail txIdx inputIdx e)) := by
  simp only [verifyInput, witnessAt, h, Bool.false_eq_true, if_false,
    getD_eq_getElem hvin, getD_eq_getElem hwit]
  rfl

/-- SWT-068 (mixed schemes in one transaction): a single tx may carry a
TAPROOT/TAPSCRIPT prevout at one index — routed to the unjudged lane —
and a BASE/WITNESS_V0 prevout at another index — routed to the adjudicated
`verifyScriptFull` lane. The lane choice is made independently per input
from that input's own prevout scriptPubKey. -/
@[rule "SWT-068"]
theorem verifyInput_mixed_schemes {height : UInt32} {tx : Tx}
    {txIdx inputIdx : Nat} {coinTap coinBase : Bitcoin.Ledger.Coin}
    (hTap : isTaprootProgram coinTap.scriptPubKey.bytes = true)
    (hBase : isTaprootProgram coinBase.scriptPubKey.bytes = false)
    (hvin1 : 1 < tx.vin.length) (hwit1 : 1 < tx.witness.length) :
    verifyInput height tx 0 coinTap txIdx 0 = .unjudgedTaproot ∧
    verifyInput height tx 1 coinBase txIdx inputIdx =
      (match verifyScriptFull
        (tx.vin[1].scriptSig.bytes.size +
          coinBase.scriptPubKey.bytes.size +
          (tx.witness[1].map (·.size)).foldl Nat.add 0 + 10)
        (getBlockScriptFlags height) default
        tx.vin[1].scriptSig.bytes coinBase.scriptPubKey.bytes
        tx.witness[1] (realCheckerOf tx 1 coinBase.value) with
      | .ok => .pass
      | .unjudged => .unjudgedTaproot
      | .fail e => .fail (CapError.scriptFail txIdx inputIdx e)) := by
  refine ⟨?_, ?_⟩
  · simp [verifyInput, hTap]
  · exact verifyInput_adjudicated_eq (height := height) (tx := tx) (i := 1)
      (coin := coinBase) (txIdx := txIdx) (inputIdx := inputIdx) hBase hvin1 hwit1

/-! ## Axiom pins (charter subset [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW67b.verifyInput_taproot_unjudged' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.verifyInput_taproot_unjudged

/-- info: 'BitcoinProofs.AF.PDW67b.verifyInput_adjudicated_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.verifyInput_adjudicated_eq

/-- info: 'BitcoinProofs.AF.PDW67b.verifyInput_mixed_schemes' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.verifyInput_mixed_schemes

end BitcoinProofs.AF.PDW67b
