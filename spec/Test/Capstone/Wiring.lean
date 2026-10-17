import Bitcoin.Serialization.Interface
import Bitcoin.Capstone.Block
import Bitcoin.Capstone.RealChecker

/-!
# Test.Capstone.Wiring — S2a gate: W14b's real ECDSA wired into W13's seam

End-to-end signature verification through the FULL stack
(W09 verifyScriptFull → W13 seam adapter → W14b `verifyImpl` → W11
sighash), on the BIP-0143 worked example (spec/vectors/bips/
bip-0143.mediawiki, "P2WPKH" example):

* input 0 — ordinary P2PK spend (legacy sighash + real ECDSA on a
  compressed key inside a 65-byte push);
* input 1 — native P2WPKH witness spend (BIP143 digest + real ECDSA).

Positive cases must PASS; a sig corrupted at one byte must FAIL (the
wiring is live, not vacuous). Compiled-runtime execution (W14b protocol:
WF-recursive EC defs are native_decide-hostile; kernel checks stay on
structural layers). Run: `lake env lean --run ../Test/Capstone/Wiring.lean`
from `core/`.
-/

namespace Test.Capstone.Wiring

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Capstone.Block
  Bitcoin.Capstone.RealChecker Bitcoin.Interpreter Bitcoin.Activation
  Bitcoin.Ledger

set_option maxRecDepth 100000

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
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

/-- The BIP-0143 example's signed transaction. -/
private def rawTx : ByteArray := fromHex
  "01000000000102fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f00000000494830450221008b9d1dc26ba6a9cb62127b02742fa9d754cd3bebf337f7a55d114c8e5cdd30be022040529b194ba3f9281a99f2b1c0a19c0489bc22ede944ccf4ecbab4cc618ef3ed01eeffffffef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a0100000000ffffffff02202cb206000000001976a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac9093510d000000001976a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac000247304402203609e17b84f6a7d30c80bfa610b5b4542f32a8a0d5447a12fb1366d7f01cc44a0220573a954c4518331561406f90300e8f3358f51928d43c212a8caed02de67eebee0121025476c2e83188368da1ff3e292e7acafcdb3566bb0ad253f62fc70f07aeee635711000000"

/-- Input 0's prevout: ordinary P2PK, 6.25 BTC. -/
private def p2pkSpk : ByteArray := fromHex
  "2103c9f4836b9a4f77fc0d81f7bcb01b7f1b35916864b9476c241ce9fc198bd25432ac"

/-- Input 1's prevout: native P2WPKH witness program, 6 BTC. -/
private def p2wpkhSpk : ByteArray := fromHex
  "00141d0f172a0ecb48aee1be1f2687d2963ae33f71a1"

private def dummyTxInW : TxIn := ⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩

private def coin (spk : ByteArray) (v : Amount) : Coin :=
  Coin.mk v 100 false (Script.mk spk)

private def flags : Bitcoin.Activation.ScriptFlags :=
  { Bitcoin.Activation.ScriptFlags.mk false false false false false false
      false with p2sh := true, witness := true }

/-- Script verdict for input `i` of `rawTx` against prevout `spk`/value. -/
private def verdict (i : Nat) (spk : ByteArray) (v : Amount) : Bool :=
  match decodeTx rawTx with
  | .error _ => false
  | .ok tx =>
    let ss := (tx.vin.getD i dummyTxInW).scriptSig.bytes
    let w := witnessAt tx i
    let wbytes := (w.map (·.size)).foldl Nat.add 0
    match verifyScriptFull (ss.size + spk.size + wbytes + 10) flags default
        ss spk w (realCheckerOf tx i v) with
    | .ok => true
    | _ => false

/-- The same tx with input 0's scriptSig signature corrupted at one byte
(offset 0x30 = 48, inside the DER r-integer) — must FAIL input 0. -/
private def badSigTx : ByteArray :=
  let c := fromHex
    "01000000000102fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f00000000494830450221008b9d1dc26ba6a9cb62127b02742fa9d754cd3bebf337f7a55d114c8e5cdd30be022040529b194ba3f9281a99f2b1c0a19c0489bc22ede944ccf4ecbab4cc618ef3ed01eeffffffef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a0100000000ffffffff02202cb206000000001976a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac9093510d000000001976a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac000247304402203609e17b84f6a7d30c80bfa610b5b4542f32a8a0d5447a12fb1366d7f01cc44a0220573a954c4518331561406f90300e8f3358f51928d43c212a8caed02de67eebee0121025476c2e83188368da1ff3e292e7acafcdb3566bb0ad253f62fc70f07aeee635711000000"
  c.set! 48 ((c.get! 48) ^^^ 1)

def main : IO Unit := do
  let mut fails := 0
  let checks : List (String × Bool) :=
    [ ("tx decodes", (decodeTx rawTx).isOk),
      ("input0 P2PK legacy+realECDSA PASSES", verdict 0 p2pkSpk 625000000),
      ("input1 P2WPKH BIP143+realECDSA PASSES", verdict 1 p2wpkhSpk 600000000),
      ("corrupted-sig tx decodes", (decodeTx badSigTx).isOk),
      ("corrupted input0 P2PK sig REJECTED (wiring live, not vacuous)",
        (match decodeTx badSigTx with
          | .error _ => false
          | .ok tx =>
            let ss := (tx.vin.getD 0 dummyTxInW).scriptSig.bytes
            match verifyScriptFull (ss.size + p2pkSpk.size + 10)
                { p2sh := true, witness := true } default
                ss p2pkSpk [] (realCheckerOf tx 0 625000000) with
            | .ok => false
            | _ => true)) ]
  for (name, ok) in checks do
    if !ok then fails := fails + 1
    IO.println ((if ok then "PASS " else "FAIL ") ++ name)
  IO.println s!"TOTAL {checks.length} FAILURES {fails}"
  if fails > 0 then throw (IO.userError "wiring test failures")

end Test.Capstone.Wiring

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := Test.Capstone.Wiring.main
